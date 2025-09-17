import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService = ApiService();

  // Current selection
  int? _selectedSalonId;
  String? salonName;
  String? salonAddress;

  // All salons (from API)
  List<dynamic> _salons = [];

  // Arrow open/close
  bool _pickerOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCachedSalon();   // Load cached values first
    _fetchSalonFromApi(); // Then update from API
  }

  // ---------- storage helpers ----------
  Future<void> _loadCachedSalon() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedSalonId = prefs.getInt('selected_salon_id');
      salonName = prefs.getString("salon_name");
      salonAddress = prefs.getString("salon_address");
    });
  }

  Future<void> _saveSelection({
    required int salonId,
    required String name,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_salon_id', salonId);
    await prefs.setString('salon_name', name);
    await prefs.setString('salon_address', address);
  }

  // ---------- api + selection ----------
  Future<void> _fetchSalonFromApi() async {
    try {
      final response = await apiService.getSalonListApi();
      if (response['success'] == true && response['data'] is List && response['data'].isNotEmpty) {
        final List data = List.from(response['data']);
        setState(() => _salons = data);

        // pick previously saved salon if available, else first
        final int index = _findSalonIndexById(_selectedSalonId) ?? 0;
        final Map<String, dynamic> chosen = Map<String, dynamic>.from(data[index]);

        final String name = (chosen['name'] ?? 'Unnamed Salon').toString();
        final String address = _formatAddressFromFirstBranch(chosen);

        // save + update ui (even if same)
        await _saveSelection(salonId: chosen['id'] as int, name: name, address: address);
        setState(() {
          _selectedSalonId = chosen['id'] as int;
          salonName = name;
          salonAddress = address;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching salon list: $e");
    }
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

    await _saveSelection(salonId: id, name: name, address: address);
    setState(() {
      _selectedSalonId = id;
      salonName = name;
      salonAddress = address;
      _pickerOpen = false; // close on select
    });
  }

  // ---------- ui ----------
  @override
  Widget build(BuildContext context) {
    final bool loadingHeader = (salonName == null || salonAddress == null);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // Header card with arrow
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
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
                                    child: SizedBox(
                                      height: 22, width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      salonName!,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                          icon: Icon(_pickerOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down),
                          onPressed: () {
                            setState(() {
                              _pickerOpen = !_pickerOpen;
                            });
                          },
                        ),
                      ],
                    ),

                    // Animated picker panel
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildSalonPicker(),
                      crossFadeState: _pickerOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // …rest of your home content here…
            ],
          ),
        ),
      ),
    );
  }

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
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            subtitle: Text(
              addr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: selected
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : const SizedBox.shrink(),
            onTap: () => _onPickSalon(s),
          );
        },
      ),
    );
  }
}
