import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/shared_profile_screen.dart';
import '../services/auth_session_manager.dart';
import '../services/language_listener.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
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

    if (!mounted) {
      return;
    }

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
    final messenger = ScaffoldMessenger.of(context);
    final logoutTitle = translateText('Logout');
    final logoutMessage = translateText('Are you sure you want to log out?');
    final cancelLabel = translateText('Cancel');
    final confirmLogoutLabel = translateText('Yes, log out');
    final failureText = translateText('Logout request failed on the server.');
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
              if (isLoggingOut) {
                return;
              }
              setSheetState(() => isLoggingOut = true);

              final success = await apiService.logoutUserAPI();
              if (!mounted || !ctx.mounted) {
                return;
              }

              setSheetState(() => isLoggingOut = false);
              Navigator.pop(ctx);

              if (!success) {
                messenger.showSnackBar(
                  SnackBar(content: Text(failureText)),
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
                    logoutTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    logoutMessage,
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
                          child: Text(cancelLabel),
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
                              : Text(confirmLogoutLabel),
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
    final messenger = ScaffoldMessenger.of(context);
    final deleteTitle = translateText('Delete Account');
    final deleteMessage =
        translateText('Are you sure you want to delete your account?');
    final cancelLabel = translateText('Cancel');
    final confirmDeleteLabel = translateText('Yes, delete');
    final deleteFailureText = translateText('Delete failed. Please try again.');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> handleDelete() async {
              if (isDeleting) {
                return;
              }
              setDialogState(() => isDeleting = true);

              final success = await apiService.deleteAccountAPI();
              if (!mounted || !ctx.mounted) {
                return;
              }

              setDialogState(() => isDeleting = false);

              if (success) {
                Navigator.pop(ctx);
                await AuthSessionManager.instance.forceLogout(
                  reason: 'user_delete_account',
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(deleteFailureText),
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                deleteTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.starColor,
                ),
              ),
              content: Text(
                deleteMessage,
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text(cancelLabel),
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
                      : Text(confirmDeleteLabel),
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

    return SharedProfileScreen(
      userName: _userName,
      phoneNumber: _phoneNumber,
      currentLanguageCode: langListener.currentLang,
      onLanguageChanged: _changeLanguage,
      onRefresh: _loadData,
      menuItems: [
        ProfileMenuItemData(
          icon: Icons.schedule_outlined,
          label: context.t('Schedule'),
          onTap: _openSchedule,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.payments_outlined,
          label: context.t('Commission'),
          onTap: () => _openDetail(translateText('Commission')),
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.rate_review_outlined,
          label: context.t('Reviews'),
          onTap: _openReviews,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.info_outline,
          label: context.t('About Salon'),
          onTap: _openAboutSalon,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.privacy_tip_outlined,
          label: context.t('Privacy Policy'),
          onTap: () => _openDoc(
            translateText('Privacy Policy'),
            'https://glowante.com/privacy-policy',
          ),
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.policy_outlined,
          label: context.t('Terms & Conditions'),
          onTap: () => _openDoc(
            translateText('Terms & Conditions'),
            'https://glowante.com/terms-of-services',
          ),
          showLeftAccent: true,
        ),
      ],
      onLogout: _showLogoutSheet,
      onDeleteAccount: _showDeleteDialog,
    );
  }
}
