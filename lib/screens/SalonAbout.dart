import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';
import '../utils/api_service.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/services.dart';

class SalonAbout extends StatefulWidget {
  const SalonAbout({Key? key, this.branchId}) : super(key: key);

  final int? branchId;

  @override
  State<SalonAbout> createState() => _SalonAboutState();
}

class _SalonAboutState extends State<SalonAbout> {
  bool _loading = true;
  int? _branchId;
  Map<String, dynamic>? _details;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveBranchId();
  }

  Future<void> _resolveBranchId() async {
    int? id = widget.branchId;
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getInt('selected_branch_id');
    }

    if (!mounted) return;

    if (id == null) {
      setState(() {
        _branchId = null;
        _details = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _branchId = id;
      _details = null;
      _error = null;
      _loading = true;
    });

    await _fetchBranchDetails(id);
  }

  Future<void> _fetchBranchDetails(int branchId) async {
    try {
      final response = await ApiService().getBranchDetail(branchId);
      Map<String, dynamic>? data;
      if (response['data'] is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(response['data'] as Map);
      } else if (response is Map<String, dynamic>) {
        data = Map<String, dynamic>.from(response);
      }

      if (!mounted) return;

      setState(() {
        _details = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _details = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.t(''); // register for language changes
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          translateText('About Salon'),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_branchId == null) {
      return _CenteredMessage(
          text: context.t('Select a branch to view details'));
    }

    if (_error != null) {
      return _CenteredMessage(
        text: context.t('Unable to load branch details.'),
        secondary: _error,
      );
    }

    final details = _details ?? const {};
    final description = (details['description'] as String?)?.trim();
    final phone = (details['phone'] ?? '').toString().trim();
    final address = details['address'] as Map<String, dynamic>?;
    final line1 = (address?['line1'] ?? '').toString().trim();
    final city = (address?['city'] ?? '').toString().trim();
    final state = (address?['state'] ?? '').toString().trim();
    final pincode = (address?['pincode'] ?? '').toString().trim();

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (description != null && description.isNotEmpty)
                ? description
                : context.t('No description available'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (phone.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.phone,
              label: context.t('Phone Number'),
              value: phone,
            ),
            const SizedBox(height: 16),
          ],
          if (line1.isNotEmpty ||
              city.isNotEmpty ||
              state.isNotEmpty ||
              pincode.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.location_on,
              label: context.t('Address'),
              value: _composeAddress(
                  line1: line1, city: city, state: state, pincode: pincode),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  String _composeAddress({
    required String line1,
    required String city,
    required String state,
    required String pincode,
  }) {
    final parts = [line1, city, state, pincode]
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.starColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.secondary});

  final String text;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              Text(
                secondary!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
