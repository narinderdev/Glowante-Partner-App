import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';
import '../widgets/app_loader.dart';

// Raw client directory for a branch — unlike OwnerBranchClientsScreen's
// engagement dashboard (which only lists clients with booking activity in
// the selected date range), this shows every client linked to the branch
// via `branches/{id}/customers-list`, including ones added by import who
// haven't booked yet.
class OwnerBranchAllClientsScreen extends StatefulWidget {
  const OwnerBranchAllClientsScreen({super.key, required this.branchId});

  final int branchId;

  @override
  State<OwnerBranchAllClientsScreen> createState() =>
      _OwnerBranchAllClientsScreenState();
}

class _OwnerBranchAllClientsScreenState
    extends State<OwnerBranchAllClientsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response =
          await _apiService.getBranchCustomersList(widget.branchId);
      final rawList = response['data'];
      final clients = rawList is List
          ? rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;
    return _clients.where((client) {
      final name = (client['name'] ?? '').toString().toLowerCase();
      final phone = (client['phoneNumber'] ?? '').toString().toLowerCase();
      final fullPhone =
          (client['fullPhoneNumber'] ?? '').toString().toLowerCase();
      final email = (client['email'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          phone.contains(query) ||
          fullPhone.contains(query) ||
          email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(title: context.t('All Clients')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TextField(
              controller: _searchController,
              cursorColor: AppColors.starColor,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.t('Search by name, phone or email'),
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF78716C),
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF78716C),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                    color: AppColors.starColor,
                    width: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: AppLoader.page()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (clients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    context.t('No clients found'),
                    style: const TextStyle(
                      color: Color(0xFF78716C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              ...clients.map((client) => _ClientTile(client: client)),
          ],
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client});

  final Map<String, dynamic> client;

  @override
  Widget build(BuildContext context) {
    final name = (client['name'] ?? '').toString().trim();
    final phone = (client['fullPhoneNumber'] ?? client['phoneNumber'] ?? '')
        .toString()
        .trim();
    final email = (client['email'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.starColor.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: AppColors.starColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.t('Unnamed') : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78716C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
