import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_session_manager.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'stylist_about_salon_screen.dart';
import 'stylist_detail_screen.dart';
import 'stylist_reviews_screen.dart';
import 'stylist_schedule_screen.dart';
import 'stylist_web_doc_screen.dart';

class StylistProfileScreen extends StatefulWidget {
  const StylistProfileScreen({super.key});

  @override
  State<StylistProfileScreen> createState() => _StylistProfileScreenState();
}

class _StylistProfileScreenState extends State<StylistProfileScreen> {
  final ApiService apiService = ApiService();

  String _userName = '';
  String _phoneNumber = '';
  StylistBranchSelection _selection = const StylistBranchSelection();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName =
        prefs.getString('firstName') ?? prefs.getString('first_name') ?? '';
    final lastName =
        prefs.getString('lastName') ?? prefs.getString('last_name') ?? '';
    final selection = await StylistBranchSelectionStore.load();

    if (!mounted) return;
    setState(() {
      _userName = '$firstName $lastName'.trim();
      _phoneNumber = prefs.getString('phone_number') ?? '';
      _selection = selection;
    });
  }

  void _changeLanguage(String langCode) {
    final langListener = Provider.of<LanguageListener>(context, listen: false);
    langListener.changeLanguage(langCode);
  }

  void _openDoc(String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StylistWebDocScreen(title: title, url: url),
      ),
    );
  }

  void _openDetail(String title) {
    final label = _selection.label.isEmpty
        ? translateText('Select a salon in Bookings first')
        : _selection.label;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StylistDetailScreen(
          title: title,
          subtitle: '$title\n\n$label',
        ),
      ),
    );
  }

  void _openSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StylistScheduleScreen(),
      ),
    );
  }

  void _openAboutSalon() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StylistAboutSalonScreen(),
      ),
    );
  }

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StylistReviewsScreen(),
      ),
    );
  }

  void _showLogoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        bool isLoggingOut = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> handleLogout() async {
              if (isLoggingOut) return;
              setSheetState(() => isLoggingOut = true);

              final success = await apiService.logoutUserAPI();
              if (!mounted) return;

              setSheetState(() => isLoggingOut = false);
              Navigator.pop(ctx);

              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t('Logout request failed on the server.'),
                    ),
                  ),
                );
              }

              await AuthSessionManager.instance.forceLogout(
                reason: success ? 'user_logout' : 'user_logout_failed',
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('Logout'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.t('Are you sure you want to log out?'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isLoggingOut ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(context.t('Cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoggingOut ? null : handleLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.starColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoggingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(context.t('Yes, log out')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> handleDelete() async {
              if (isDeleting) return;
              setDialogState(() => isDeleting = true);

              final success = await apiService.deleteAccountAPI();
              if (!mounted) return;

              setDialogState(() => isDeleting = false);

              if (success) {
                Navigator.pop(ctx);
                await AuthSessionManager.instance.forceLogout(
                  reason: 'user_delete_account',
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t('Delete failed. Please try again.'),
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                context.t('Delete Account'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.starColor,
                ),
              ),
              content: Text(
                context.t('Are you sure you want to delete your account?'),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text(context.t('Cancel')),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : handleDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.t('Yes, delete')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langListener = Provider.of<LanguageListener>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.t('Profile'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.starColor, AppColors.getStartedButton],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.starColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.starColor.withOpacity(0.12),
                    child: const Icon(
                      Icons.person,
                      size: 38,
                      color: AppColors.starColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName.isEmpty ? context.t('Profile') : _userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _phoneNumber,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Language'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _changeLanguage('en'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: langListener.currentLang == 'en'
                                ? AppColors.starColor
                                : Colors.white,
                            foregroundColor: langListener.currentLang == 'en'
                                ? Colors.white
                                : Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(context.t('English')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _changeLanguage('hi'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: langListener.currentLang == 'hi'
                                ? AppColors.starColor
                                : Colors.white,
                            foregroundColor: langListener.currentLang == 'hi'
                                ? Colors.white
                                : Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('हिंदी'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Schedule'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _openSchedule,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(context.t('Privacy Policy')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _openDoc(
                      translateText('Privacy Policy'),
                      'https://glowante.com/privacy-policy',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: Text(context.t('Terms & Conditions')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _openDoc(
                      translateText('Terms & Conditions'),
                      'https://glowante.com/terms-of-services',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.t('About Salon')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _openAboutSalon,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: Text(context.t('Reviews')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _openReviews,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(context.t('Commission')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _openDetail(translateText('Commission')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showLogoutSheet,
              icon: const Icon(Icons.logout),
              label: Text(context.t('Logout')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showDeleteDialog,
              icon: const Icon(Icons.delete_forever),
              label: Text(context.t('Delete Account')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
