import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../utils/localization_helper.dart';
import '../widgets/app_loader.dart';

/// Lists salon invitations sent to the logged-in user's own phone number
/// (see invitation_plan.md Phase 1C) and lets them decline one. Phase 1
/// intentionally has no "accept from this list" action — accept still
/// requires the raw invitation token from the email link.
class MyTeamInvitationsScreen extends StatefulWidget {
  const MyTeamInvitationsScreen({super.key});

  @override
  State<MyTeamInvitationsScreen> createState() =>
      _MyTeamInvitationsScreenState();
}

const _myInvitationsGold = Color(0xFF8B6500);
const _myInvitationsInk = Color(0xFF1F1A16);
const _myInvitationsMuted = Color(0xFF776D64);
const _myInvitationsBorder = Color(0xFFE8DDD2);

class _MyTeamInvitationsScreenState extends State<MyTeamInvitationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _invitations = const [];
  final Set<int> _decliningIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response =
          await ApiService().getMyTeamInvitations(status: 'PENDING');
      if (!mounted) return;
      if (response['success'] == true) {
        final data = response['data'];
        final rawItems = data is Map ? data['items'] : null;
        setState(() {
          _invitations = (rawItems is List ? rawItems : const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = extractMessage(
            response,
            fallback: 'Unable to load invitations',
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = extractErrorMessage(
          e,
          fallback: 'Unable to load invitations',
        );
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _salon(Map<String, dynamic> invitation) {
    final salon = invitation['salon'];
    return salon is Map ? Map<String, dynamic>.from(salon) : null;
  }

  String _salonName(Map<String, dynamic> invitation) {
    return (_salon(invitation)?['name'] ?? '').toString().trim();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _sentAgoLabel(Map<String, dynamic> invitation) {
    final sentAt = _parseDate(invitation['sentAt']);
    if (sentAt == null) return '';
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return translateText('Sent just now');
    if (diff.inHours < 1) {
      return translateText('Sent {n}m ago', params: {'n': '${diff.inMinutes}'});
    }
    if (diff.inDays < 1) {
      return translateText('Sent {n}h ago', params: {'n': '${diff.inHours}'});
    }
    return translateText('Sent {n}d ago', params: {'n': '${diff.inDays}'});
  }

  String _expiresLabel(Map<String, dynamic> invitation) {
    final expiresAt = _parseDate(invitation['expiresAt']);
    if (expiresAt == null) return '';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return translateText('Expired');
    if (diff.inDays >= 1) {
      return translateText('Expires in {n}d', params: {'n': '${diff.inDays}'});
    }
    if (diff.inHours >= 1) {
      return translateText('Expires in {n}h', params: {'n': '${diff.inHours}'});
    }
    return translateText('Expires in {n}m', params: {'n': '${diff.inMinutes}'});
  }

  Future<void> _decline(Map<String, dynamic> invitation) async {
    final id = _asInt(invitation['id']);
    if (id == null || _decliningIds.contains(id)) return;

    final salonName = _salonName(invitation);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(translateText('Decline invitation')),
        content: Text(
          salonName.isEmpty
              ? translateText('Decline this salon invitation?')
              : translateText(
                  'Decline the invitation to join {salon}?',
                  params: {'salon': salonName},
                ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _myInvitationsGold),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(translateText('No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              translateText('Yes, decline'),
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _decliningIds.add(id));
    try {
      final response = await ApiService().declineTeamInvitation(id);
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Invitation declined'));
        setState(() {
          _invitations =
              _invitations.where((item) => _asInt(item['id']) != id).toList();
        });
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(
            response,
            fallback: 'Unable to decline this invitation',
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(
          e,
          fallback: 'Unable to decline this invitation',
        ),
      );
    } finally {
      if (mounted) setState(() => _decliningIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _myInvitationsGold,
        centerTitle: true,
        title: Text(
          translateText('My Invitations'),
          style: const TextStyle(
            color: _myInvitationsGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _myInvitationsBorder),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.starColor,
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _invitations.isEmpty) {
      return Center(child: AppLoader.page());
    }
    if (_errorMessage != null && _invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded, color: AppColors.red, size: 44),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _myInvitationsInk, fontSize: 14),
          ),
        ],
      );
    }
    if (_invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.mail_outline_rounded,
              color: _myInvitationsGold, size: 48),
          const SizedBox(height: 14),
          Text(
            translateText('No pending invitations'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _myInvitationsInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translateText(
              "Salon invitations sent to your phone number will show up here.",
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _myInvitationsMuted, fontSize: 12.5),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _invitations.length,
      itemBuilder: (context, index) {
        final invitation = _invitations[index];
        final id = _asInt(invitation['id']);
        final isDeclining = id != null && _decliningIds.contains(id);
        final salonName = _salonName(invitation);
        final salonImageUrl =
            (_salon(invitation)?['imageUrl'] ?? '').toString().trim();
        final sentLabel = _sentAgoLabel(invitation);
        final expiresLabel = _expiresLabel(invitation);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _myInvitationsBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: Container(
                      width: 44,
                      height: 44,
                      color: const Color(0xFFF5EAD2),
                      child: salonImageUrl.isEmpty
                          ? const Icon(
                              Icons.storefront_rounded,
                              color: _myInvitationsGold,
                              size: 22,
                            )
                          : Image.network(
                              salonImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.storefront_rounded,
                                color: _myInvitationsGold,
                                size: 22,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salonName.isEmpty
                              ? translateText('You have been invited')
                              : salonName,
                          style: const TextStyle(
                            color: _myInvitationsInk,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          translateText('Pending'),
                          style: const TextStyle(
                            color: _myInvitationsGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: isDeclining ? null : () => _decline(invitation),
                    child: isDeclining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            translateText('Decline'),
                            style: const TextStyle(color: AppColors.red),
                          ),
                  ),
                ],
              ),
              if (sentLabel.isNotEmpty || expiresLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: _myInvitationsBorder),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sentLabel,
                      style: const TextStyle(
                        color: _myInvitationsMuted,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      expiresLabel,
                      style: const TextStyle(
                        color: _myInvitationsMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
