import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService = ApiService();

  // ------- selection (from header) -------
  int? _selectedSalonId;
  int? _selectedBranchId; // auto-chosen from salon
  String? salonName;
  String? salonAddress;

  // All salons (from API)
  List<dynamic> _salons = [];
  bool _pickerOpen = false;

  // ------- bookings state (embedded) -------
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> teamMembers = [];
  List<String> timeSlots = [];
  DateTime selectedDate = DateTime.now();

  String? _branchStartTimeStr; // e.g. "08:00:00"
  String? _branchEndTimeStr;   // e.g. "20:00:00"

  int pendingCount = 0;
  int cancelledCount = 0;
  int completedCount = 0;
  int confirmedCount = 0;

  // grid layout
  static const double _rowHeight = 44.0; // 15-min slot height
  static const double _colWidth = 140.0; // staff column width

  // scroll sync
  final ScrollController _timeColumnVController = ScrollController();
  final ScrollController _gridVController = ScrollController();
  final ScrollController _headerHController = ScrollController();
  final ScrollController _gridHController = ScrollController();
  bool _syncingV = false;
  bool _syncingH = false;

  @override
  void initState() {
    super.initState();
    _loadCachedSelection();
    _fetchSalons();

    // vertical sync
    _timeColumnVController.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_gridVController.hasClients) {
        final off = _timeColumnVController.offset;
        if ((_gridVController.offset - off).abs() > 0.5) {
          _gridVController.jumpTo(off);
        }
      }
      _syncingV = false;
    });
    _gridVController.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_timeColumnVController.hasClients) {
        final off = _gridVController.offset;
        if ((_timeColumnVController.offset - off).abs() > 0.5) {
          _timeColumnVController.jumpTo(off);
        }
      }
      _syncingV = false;
    });

    // horizontal sync
    _headerHController.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_gridHController.hasClients) {
        final off = _headerHController.offset;
        if ((_gridHController.offset - off).abs() > 0.5) {
          _gridHController.jumpTo(off);
        }
      }
      _syncingH = false;
    });
    _gridHController.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_headerHController.hasClients) {
        final off = _gridHController.offset;
        if ((_headerHController.offset - off).abs() > 0.5) {
          _headerHController.jumpTo(off);
        }
      }
      _syncingH = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timeColumnVController.hasClients && _gridVController.hasClients) {
        _gridVController.jumpTo(_timeColumnVController.offset);
      }
      if (_headerHController.hasClients && _gridHController.hasClients) {
        _gridHController.jumpTo(_headerHController.offset);
      }
    });
  }

  // ------------------ storage ------------------
  Future<void> _loadCachedSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSalonId  = prefs.getInt('selected_salon_id');
      _selectedBranchId = prefs.getInt('selected_branch_id');
      salonName   = prefs.getString('salon_name');
      salonAddress= prefs.getString('salon_address');
    });
  }

  Future<void> _saveSelection({
    required int salonId,
    required String name,
    required String address,
    int? branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_salon_id', salonId);
    await prefs.setString('salon_name', name);
    await prefs.setString('salon_address', address);
    if (branchId != null) {
      await prefs.setInt('selected_branch_id', branchId);
    }
  }

  // ------------------ api + selection ------------------
  Future<void> _fetchSalons() async {
    try {
      final response = await apiService.getSalonListApi();
      if (response['success'] == true && response['data'] is List && response['data'].isNotEmpty) {
        final List data = List.from(response['data']);
        setState(() => _salons = data);

        // choose previously saved salon (if exists) else first
        final int index = _findSalonIndexById(_selectedSalonId) ?? 0;
        final Map<String, dynamic> chosen = Map<String, dynamic>.from(data[index]);

        final String name = (chosen['name'] ?? 'Unnamed Salon').toString();
        final String address = _formatAddressFromFirstBranch(chosen);

        // pick branch: prefer saved one if it belongs to this salon; else first branch
        final int? restoredBranchId = _selectedBranchId;
        final int autoBranchId = _pickBranchForSalon(chosen, restoredBranchId);

        await _saveSelection(
          salonId: chosen['id'] as int,
          name: name,
          address: address,
          branchId: autoBranchId,
        );

        setState(() {
          _selectedSalonId  = chosen['id'] as int;
          _selectedBranchId = autoBranchId;
          salonName = name;
          salonAddress = address;
        });

        if (_selectedBranchId != null) {
          await _loadBranchData(_selectedBranchId!, selectedDate);
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching salons: $e");
    }
  }

  int _pickBranchForSalon(Map<String, dynamic> salon, int? preferId) {
    final branches = salon['branches'] as List? ?? const [];
    if (branches.isEmpty) return -1;
    if (preferId != null && branches.any((b) => b['id'] == preferId)) {
      return preferId;
    }
    return branches.first['id'] as int;
  }

  int? _findSalonIndexById(int? id) {
    if (id == null) return null;
    final i = _salons.indexWhere((s) => (s is Map && s['id'] == id));
    return i >= 0 ? i : null;
  }

  String _formatAddressFromFirstBranch(Map<String, dynamic> salon) {
    final branches = salon['branches'] as List? ?? const [];
    final addr = branches.isNotEmpty ? branches.first['address'] as Map<String, dynamic>? : null;
    if (addr == null) return 'No address available';
    final parts = [
      addr['line1'],
      addr['city'],
      addr['state'],
      addr['postalCode'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString());
    return parts.join(', ');
  }

  Future<void> _onPickSalon(Map<String, dynamic> salon) async {
    final id = salon['id'] as int;
    final name = (salon['name'] ?? 'Unnamed Salon').toString();
    final address = _formatAddressFromFirstBranch(salon);
    final branchId = _pickBranchForSalon(salon, null);

    await _saveSelection(salonId: id, name: name, address: address, branchId: branchId);
    setState(() {
      _selectedSalonId  = id;
      _selectedBranchId = branchId;
      salonName = name;
      salonAddress = address;
      _pickerOpen = false;
    });

    if (_selectedBranchId != null) {
      await _loadBranchData(_selectedBranchId!, selectedDate);
    }
  }

  // ------------------ branch data (same behavior as Bookings.dart but inline) ------------------
  Future<void> _loadBranchData(int branchId, DateTime date) async {
    await Future.wait([
      _getTeamMembers(branchId),
      _getBookingsByDate(branchId, date),
    ]);
  }

  Future<void> _getTeamMembers(int branchId) async {
    try {
      final response = await ApiService.getTeamMembers(branchId);
      if (response != null && response['success'] == true && response['data'] != null) {
        setState(() => teamMembers = List<Map<String, dynamic>>.from(response['data']));
      } else {
        setState(() => teamMembers = []);
      }
    } catch (e) {
      debugPrint('Error fetching team members: $e');
      setState(() => teamMembers = []);
    }
  }

  List<String> _generateTimeSlots(String startTime, String endTime) {
    final slots = <String>[];
    DateTime start = DateFormat("HH:mm:ss").parse(startTime);
    DateTime end   = DateFormat("HH:mm:ss").parse(endTime);
    DateTime effectiveEnd = end.subtract(const Duration(minutes: 15));
    while (start.isBefore(effectiveEnd) || start.isAtSameMomentAs(effectiveEnd)) {
      slots.add(DateFormat("h:mm a").format(start));
      start = start.add(const Duration(minutes: 15));
    }
    return slots;
  }

  Future<void> _getBookingsByDate(int branchId, DateTime date) async {
    try {
      String formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final response = await apiService.fetchAppointments(branchId, formattedDate);

      if (response != null && response['success'] == true && response['data'] != null) {
        final List<dynamic> appointments = response['data'];

        String startTime = '08:00:00';
        String endTime = '20:00:00';
        if (appointments.isNotEmpty && appointments.first['branch'] != null) {
          startTime = (appointments.first['branch']['startTime'] ?? startTime).toString();
          endTime   = (appointments.first['branch']['endTime']   ?? endTime).toString();
        }

        setState(() {
          timeSlots = _generateTimeSlots(startTime, endTime);
          _branchStartTimeStr = startTime;
          _branchEndTimeStr   = endTime;
          bookings = List<Map<String, dynamic>>.from(appointments);
        });
        _recomputeStatusCounts();
      } else {
        setState(() {
          bookings = [];
          timeSlots = [];
          pendingCount = 0;
          cancelledCount = 0;
          completedCount = 0;
          confirmedCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
    }
  }

  void _recomputeStatusCounts() {
    int sumStatus(String status) {
      int t = 0;
      for (final b in bookings) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        if (s == status) {
          final items = (b['items'] as List?) ?? const [];
          t += items.isNotEmpty ? items.length : 1;
        }
      }
      return t;
    }

    setState(() {
      pendingCount   = sumStatus('PENDING');
      cancelledCount = sumStatus('CANCELLED');
      completedCount = sumStatus('COMPLETED');
      confirmedCount = sumStatus('CONFIRMED');
    });
  }

  // ------------------ time helpers ------------------
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    int h = 0, m = 0, s = 0;
    try {
      final parts = timeStr.split(':');
      if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
      if (parts.length > 2) s = int.tryParse(parts[2]) ?? 0;
    } catch (_) {}
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  DateTime? _parseLocal(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  // ------------------ grid helpers (same visual as Bookings.dart merged view) ------------------
  int _findMemberColumnForItem(Map<String, dynamic> item) {
    final dynamic userId = item['assignedUserBranch']?['user']?['id'] ??
        item['assignedUserBranch']?['userId'] ??
        item['user']?['id'] ??
        item['userId'];
    if (userId == null) return -1;
    final idx = teamMembers.indexWhere((m) {
      final mid = m['id'] ?? m['user']?['id'] ?? m['userId'];
      return mid == userId;
    });
    return idx;
  }

  List<Widget> _buildBackgroundGrid() {
    final List<Widget> widgets = [];
    for (int r = 0; r < timeSlots.length; r++) {
      widgets.add(Positioned(
        top: r * _rowHeight,
        left: 0,
        right: 0,
        height: _rowHeight,
        child: Container(
          decoration: BoxDecoration(
            color: r % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ));
    }
    for (int c = 1; c < (teamMembers.isEmpty ? 1 : teamMembers.length); c++) {
      widgets.add(Positioned(
        top: 0,
        bottom: 0,
        left: c * _colWidth - 1,
        width: 1,
        child: Container(color: Colors.grey.shade300),
      ));
    }
    return widgets;
  }

  String _fmtTimeRange(DateTime s, DateTime e) {
    final f = DateFormat('h:mma');
    return '${f.format(s).toLowerCase()} - ${f.format(e).toLowerCase()}';
  }

  List<Map<String, dynamic>> _collectMergedSegments() {
    if (bookings.isEmpty || _branchStartTimeStr == null || _branchEndTimeStr == null) {
      return const [];
    }

    int? _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final DateTime dayStart = _combineDateAndTime(selectedDate, _branchStartTimeStr!);
    final DateTime dayEnd   = _combineDateAndTime(selectedDate, _branchEndTimeStr!);

    final List<Map<String, dynamic>> flat = [];
    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toUpperCase();
      final customer = booking['user'] as Map<String, dynamic>?;
      final customerName = [
        customer?['firstName']?.toString() ?? '',
        customer?['lastName']?.toString() ?? ''
      ].where((s) => s.isNotEmpty).join(' ').trim();

      final items = (booking['items'] as List?) ?? const [];
      for (final raw in items) {
        final item = Map<String, dynamic>.from(raw as Map);

        final int col = _findMemberColumnForItem(item);
        if (col < 0) continue;

        final staffUserId = item['assignedUserBranch']?['user']?['id'] ??
            item['assignedUserBranch']?['userId'] ??
            item['user']?['id'] ??
            item['userId'];

        DateTime? s = _parseLocal(item['startAt']) ?? _parseLocal(booking['startAt']);
        DateTime? e = _parseLocal(item['endAt'])   ?? _parseLocal(booking['endAt']);
        if (s == null || e == null) continue;

        if (s.isBefore(dayStart)) s = dayStart;
        if (e.isAfter(dayEnd)) e = dayEnd;
        if (!e.isAfter(s)) continue;

        flat.add({
          'booking': booking,
          'item': item,
          'appointmentId': booking['id'],
          'col': col,
          'customerId': booking['user']?['id'] ?? booking['userId'],
          'customerName': customerName.isEmpty ? 'Customer' : customerName,
          'staffUserId': staffUserId,
          'status': status,
          'start': s,
          'end': e,
          'service': item['branchService']?['displayName']?.toString() ?? 'Service',
          'priceMinor': _toInt(item['branchService']?['priceMinor']),
        });
      }
    }

    if (flat.isEmpty) return const [];

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final it in flat) {
      final key = '${it['col']}|${it['customerId']}|${it['staffUserId']}|${it['status']}';
      (groups[key] ??= <Map<String, dynamic>>[]).add(it);
    }

    final List<Map<String, dynamic>> segments = [];
    for (final g in groups.values) {
      g.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
      if (g.isEmpty) continue;

      int col = g.first['col'] as int;
      String status = g.first['status'] as String;
      String customerName = g.first['customerName'] as String;
      DateTime segStart = g.first['start'] as DateTime;
      DateTime segEnd   = g.first['end'] as DateTime;
      final List<String> services = [g.first['service'] as String];
      int? priceTotal = g.first['priceMinor'] as int?;
      final List<Map<String, dynamic>> segItems = [
        {
          'booking': g.first['booking'],
          'item': g.first['item'],
          'appointmentId': g.first['appointmentId'],
          'start': segStart,
          'end': segEnd,
          'service': g.first['service'],
          'priceMinor': g.first['priceMinor'],
        }
      ];

      for (int i = 1; i < g.length; i++) {
        final curr = g[i];
        final s = curr['start'] as DateTime;
        final e = curr['end'] as DateTime;

        if (s.isAtSameMomentAs(segEnd)) {
          segEnd = e;
          services.add(curr['service'] as String);
          final p = curr['priceMinor'] as int?;
          if (p != null) priceTotal = (priceTotal ?? 0) + p;

          segItems.add({
            'booking': curr['booking'],
            'item': curr['item'],
            'appointmentId': curr['appointmentId'],
            'start': s,
            'end': e,
            'service': curr['service'],
            'priceMinor': curr['priceMinor'],
          });
        } else {
          segments.add({
            'col': col,
            'status': status,
            'customerName': customerName,
            'start': segStart,
            'end': segEnd,
            'services': List<String>.from(services),
            'priceTotal': priceTotal,
            'items': List<Map<String, dynamic>>.from(segItems),
          });

          col = curr['col'] as int;
          status = curr['status'] as String;
          customerName = curr['customerName'] as String;
          segStart = s;
          segEnd = e;
          services
            ..clear()
            ..add(curr['service'] as String);
          priceTotal = curr['priceMinor'] as int?;
          segItems
            ..clear()
            ..add({
              'booking': curr['booking'],
              'item': curr['item'],
              'appointmentId': curr['appointmentId'],
              'start': s,
              'end': e,
              'service': curr['service'],
              'priceMinor': curr['priceMinor'],
            });
        }
      }

      segments.add({
        'col': col,
        'status': status,
        'customerName': customerName,
        'start': segStart,
        'end': segEnd,
        'services': List<String>.from(services),
        'priceTotal': priceTotal,
        'items': List<Map<String, dynamic>>.from(segItems),
      });
    }

    return segments;
  }

  void _openMergedSegmentSheet(Map<String, dynamic> seg) {
    final DateTime s = seg['start'] as DateTime;
    final DateTime e = seg['end'] as DateTime;
    final String status = (seg['status'] as String).toUpperCase();
    final String customerName = seg['customerName'] as String? ?? 'Customer';
    final int? priceTotal = seg['priceTotal'] as int?;
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(seg['items'] as List);

    final List<int> apptIds = items
        .map((it) => (it['appointmentId'] as int?))
        .where((id) => id != null)
        .cast<int>()
        .toSet()
        .toList()
      ..sort();

    final String timeRange = _fmtTimeRange(s, e);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool loadingConfirm = false;

        Future<void> onConfirmAll() async {
          if (_selectedBranchId == null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Please select a branch first.')));
            return;
          }
          if (status != 'PENDING' || apptIds.isEmpty) return;

          loadingConfirm = true;
          (ctx as Element).markNeedsBuild();

          int ok = 0, fail = 0;
          for (final id in apptIds) {
            try {
              final resp = await ApiService().confirmAppointment(
                branchId: _selectedBranchId!,
                appointmentId: id,
              );
              if (resp['success'] == true) {
                ok++;
              } else {
                fail++;
              }
            } catch (_) {
              fail++;
            }
          }

          loadingConfirm = false;
          (ctx as Element).markNeedsBuild();

          Navigator.pop(context);
          if (_selectedBranchId != null) {
            await _getBookingsByDate(_selectedBranchId!, selectedDate);
          }

          final msg = fail == 0 ? 'Confirmed $ok appointment(s).' : 'Confirmed $ok, failed $fail.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }

        return FractionallySizedBox(
          heightFactor: 0.60,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(timeRange, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text('Status: $status', style: const TextStyle(color: Colors.black54)),
                if (priceTotal != null) ...[
                  const SizedBox(height: 4),
                  Text('Total Price: ₹$priceTotal', style: const TextStyle(color: Colors.black87)),
                ],
                const SizedBox(height: 12),
                const Text('Services', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final String name = (it['service']?.toString() ?? 'Service');
                      final int? priceMinor = it['priceMinor'] as int?;
                      final String priceText = priceMinor != null ? '₹$priceMinor' : '';
                      final String range = _fmtTimeRange(it['start'] as DateTime, it['end'] as DateTime);

                      return ListTile(
                        dense: true,
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(range),
                        trailing: priceText.isNotEmpty
                            ? Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600))
                            : null,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (status == 'PENDING' && !loadingConfirm) ? onConfirmAll : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: loadingConfirm
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(apptIds.length <= 1 ? 'Confirm' : 'Confirm All (${apptIds.length})'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBookingBlocks() {
    if (bookings.isEmpty || timeSlots.isEmpty) return const <Widget>[];

    final startStr = _branchStartTimeStr ?? '08:00:00';
    final DateTime dayStart = _combineDateAndTime(selectedDate, startStr);

    final merged = _collectMergedSegments();
    final List<Widget> blocks = [];

    for (final seg in merged) {
      final int col = seg['col'] as int;
      final String status = (seg['status'] as String).toUpperCase();
      final DateTime s = seg['start'] as DateTime;
      final DateTime e = seg['end'] as DateTime;
      final int minutesFromStart = s.difference(dayStart).inMinutes;
      final int totalMin = e.difference(s).inMinutes;

      final double top = (minutesFromStart / 15.0) * _rowHeight;
      final double height = (totalMin / 15.0) * _rowHeight;
      final double left = col * _colWidth + 6;
      final double width = _colWidth - 12;

      Color bg = Colors.blue.shade300;
      if (status == 'PENDING')   bg = Colors.orange.shade300;
      if (status == 'CANCELLED') bg = Colors.red.shade300;
      if (status == 'COMPLETED') bg = Colors.green.shade300;

      final String customerName = seg['customerName'] as String? ?? 'Customer';
      final List<String> services = List<String>.from(seg['services'] as List);
      final int moreCount = (services.length > 1) ? services.length - 1 : 0;
      final String headService = services.isNotEmpty ? services.first : 'Service';

      final int? priceTotal = seg['priceTotal'] as int?;
      final String priceText = priceTotal != null ? '₹$priceTotal' : '';

      final String timeRange = _fmtTimeRange(s, e);

      blocks.add(Positioned(
        left: left,
        top: top,
        width: width,
        height: height < 44 ? 44 : height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openMergedSegmentSheet(seg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: bg,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        Text(
                          moreCount > 0 ? '$headService + $moreCount more' : headService,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87),
                        ),
                        if (priceText.isNotEmpty)
                          Text(priceText, style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(timeRange, style: const TextStyle(color: Colors.black87, fontSize: 10)),
                        Text(status, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    return blocks;
  }

  // ------------------ date nav ------------------
  void _changeDate(bool isNext) async {
    setState(() {
      selectedDate = isNext ? selectedDate.add(const Duration(days: 1))
                            : selectedDate.subtract(const Duration(days: 1));
    });
    if (_selectedBranchId != null) {
      await _getBookingsByDate(_selectedBranchId!, selectedDate);
    }
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    final bool loadingHeader = (salonName == null || salonAddress == null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // salon card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: loadingHeader
                              ? const SizedBox(
                                  height: 22,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(salonName!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            salonAddress!,
                                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                        IconButton(
                          icon: Icon(_pickerOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          onPressed: () => setState(() => _pickerOpen = !_pickerOpen),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildSalonPicker(),
                      crossFadeState: _pickerOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            ),
            // --- Specialists section (now padded like the salon card) ---
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            "Specialists",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "View all",
            style: TextStyle(color: Colors.orange, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // ✅ Legends
      Row(
        children: [
          _legendDot(Colors.green, "Present"),
          const SizedBox(width: 10),
          _legendDot(Colors.red, "Absent"),
          const SizedBox(width: 10),
          _legendDot(Colors.orange, "Break"),
        ],
      ),
      const SizedBox(height: 20),

      // ✅ Static placeholders
      const Center(
        child: Text(
          "No specialists available",
          style: TextStyle(color: Colors.grey),
        ),
      ),
    ],
  ),
),

            // status counts
            if (_selectedBranchId != null) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _statusBox('Pending', pendingCount, Colors.orange),
                    _statusBox('Cancelled', cancelledCount, Colors.red),
                    _statusBox('Completed', completedCount, Colors.green),
                    _statusBox('Confirmed', confirmedCount, Colors.blue),
                  ],
                ),
              ),
            ],

            // date row
            if (_selectedBranchId != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDate(false)),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(7, (index) {
                            final date = selectedDate.add(Duration(days: index - 3));
                            final bool isSelected = _isSameDay(date, selectedDate);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: GestureDetector(
                                onTap: () async {
                                  setState(() => selectedDate = date);
                                  if (_selectedBranchId != null) {
                                    await _getBookingsByDate(_selectedBranchId!, selectedDate);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(DateFormat('EEE').format(date),
                                          style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
                                      Text(DateFormat('d').format(date),
                                          style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeDate(true)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // timetable grid
            Expanded(
              child: (_selectedBranchId == null)
                  ? const Center(child: Text('Select a salon above to view bookings'))
                  : Container(
                      color: const Color(0xFFF7F4F1),
                      child: Column(
                        children: [
                          // header row: Time + members
                          Row(
                            children: [
                              Container(
                                width: 100,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade600,
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _headerHController,
                                  scrollDirection: Axis.horizontal,
                                  primary: false,
                                  physics: const ClampingScrollPhysics(),
                                  child: Row(
                                    children: List.generate(teamMembers.length, (index) {
                                      final m = teamMembers[index];
                                      return Container(
                                        width: _colWidth,
                                        height: 44,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          border: Border(
                                            top: BorderSide(color: Colors.grey.shade300),
                                            right: BorderSide(color: Colors.grey.shade300),
                                            bottom: BorderSide(color: Colors.grey.shade300),
                                          ),
                                        ),
                                        child: Text(
                                          '${m['firstName']} ${m['lastName']}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 1, thickness: 1),

                          // body
                          Expanded(
                            child: Row(
                              children: [
                                // time labels
                                SizedBox(
                                  width: 100,
                                  child: timeSlots.isEmpty
                                      ? const SizedBox()
                                      : NotificationListener<ScrollNotification>(
                                          onNotification: (n) {
                                            if (n.metrics.axis == Axis.vertical) {
                                              if (!_syncingV && _gridVController.hasClients) {
                                                _syncingV = true;
                                                final off = _timeColumnVController.offset;
                                                if ((_gridVController.offset - off).abs() > 0.5) {
                                                  _gridVController.jumpTo(off);
                                                }
                                                _syncingV = false;
                                              }
                                            }
                                            return false;
                                          },
                                          child: ListView.builder(
                                            controller: _timeColumnVController,
                                            primary: false,
                                            physics: const ClampingScrollPhysics(),
                                            dragStartBehavior: DragStartBehavior.start,
                                            itemExtent: _rowHeight,
                                            itemCount: timeSlots.length,
                                            itemBuilder: (context, i) {
                                              return Container(
                                                alignment: Alignment.centerLeft,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(
                                                  color: i % 2 == 0 ? Colors.white : const Color(0xFFF0F0F0),
                                                  border: Border(
                                                    right: BorderSide(color: Colors.grey.shade300),
                                                    bottom: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                ),
                                                child: Text(timeSlots[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                              );
                                            },
                                          ),
                                        ),
                                ),
                                // grid body
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _gridHController,
                                    scrollDirection: Axis.horizontal,
                                    primary: false,
                                    physics: const ClampingScrollPhysics(),
                                    child: SizedBox(
                                      width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
                                      child: timeSlots.isEmpty
                                          ? const Center(child: Text('No time slots available'))
                                          : NotificationListener<ScrollNotification>(
                                              onNotification: (n) {
                                                if (n.metrics.axis == Axis.vertical) {
                                                  if (!_syncingV && _timeColumnVController.hasClients) {
                                                    _syncingV = true;
                                                    final off = _gridVController.offset;
                                                    if ((_timeColumnVController.offset - off).abs() > 0.5) {
                                                      _timeColumnVController.jumpTo(off);
                                                    }
                                                    _syncingV = false;
                                                  }
                                                }
                                                return false;
                                              },
                                              child: SingleChildScrollView(
                                                controller: _gridVController,
                                                primary: false,
                                                physics: const ClampingScrollPhysics(),
                                                child: SizedBox(
                                                  width: (teamMembers.isEmpty ? 1 : teamMembers.length) * _colWidth,
                                                  height: timeSlots.length * _rowHeight,
                                                  child: Stack(
                                                    children: [
                                                      ..._buildBackgroundGrid(),
                                                      ..._buildBookingBlocks(),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // salon picker (no branch dropdown here)
  Widget _buildSalonPicker() {
    if (_salons.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No salons available'),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _salons.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (context, index) {
          final s = Map<String, dynamic>.from(_salons[index] as Map);
          final int id = s['id'] as int;
          final bool selected = id == _selectedSalonId;
          final String name = (s['name'] ?? 'Unnamed Salon').toString();
          final String addr = _formatAddressFromFirstBranch(s);

          return ListTile(
            dense: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
            subtitle: Text(addr, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: selected ? const Icon(Icons.check_circle, color: Colors.blue) : const SizedBox.shrink(),
            onTap: () => _onPickSalon(s),
          );
        },
      ),
    );
  }

  Widget _statusBox(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timeColumnVController.dispose();
    _gridVController.dispose();
    _headerHController.dispose();
    _gridHController.dispose();
    super.dispose();
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
