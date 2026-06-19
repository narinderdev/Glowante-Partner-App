import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/shared_profile_screen.dart';
import '../services/auth_session_manager.dart';
import '../services/language_listener.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';
import 'web_doc_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService apiService = ApiService();

  String? userName;
  String? phoneNumber;

  void _logProfile(String event, {Object? details}) {
    debugPrint(
      '[OwnerProfile] $event${details == null ? '' : ' | $details'}',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      final firstName =
          prefs.getString('firstName') ?? prefs.getString('first_name') ?? '';
      final lastName =
          prefs.getString('lastName') ?? prefs.getString('last_name') ?? '';
      userName = '$firstName $lastName'.trim();
      phoneNumber = prefs.getString('phone_number') ?? '';
    });
  }

  void _changeLanguage(String langCode) {
    _logProfile('language_changed', details: langCode);
    final langListener = Provider.of<LanguageListener>(context, listen: false);
    langListener.changeLanguage(langCode);
  }

  void _showLogoutModal(BuildContext context) {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final logoutTitle = translateText('Logout');
    final logoutMessage = translateText('Are you sure you want to log out?');
    final cancelLabel = translateText('Cancel');
    final confirmLogoutLabel = translateText('Yes, log out');
    final failureText = translateText('Logout request failed on the server.');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoggingOut
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _showDeleteAccountDialog(BuildContext context) {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final salonListCubit = context.read<SalonListCubit>();
    final categoryCubit = context.read<CategoryCubit>();
    final deleteTitle = translateText('Delete Account');
    final deleteMessage =
        translateText('Are you sure you want to delete your account?');
    final cancelLabel = translateText('Cancel');
    final confirmDeleteLabel = translateText('Yes, delete');
    final deleteFailureText = translateText('Delete failed. Please try again.');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
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
                salonListCubit.clear();
                categoryCubit.clear();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
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
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text(cancelLabel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isDeleting ? null : handleDelete,
                  child: isDeleting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(confirmDeleteLabel),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final langListener = Provider.of<LanguageListener>(context);
    final menuItems = <ProfileMenuItemData>[
      ProfileMenuItemData(
        icon: Icons.shield_outlined,
        label: context.t('Account Security'),
        subtitle: context.t('Passwords & 2FA'),
        onTap: () {
          _logProfile('open_account_security');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _AccountSecurityScreen()),
          );
        },
      ),
      ProfileMenuItemData(
        icon: Icons.privacy_tip_outlined,
        label: context.t('Privacy Policy'),
        subtitle: context.t('Data usage & protection'),
        onTap: () {
          _logProfile('open_privacy_policy');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WebDocScreen(
                title: translateText('Privacy Policy'),
                url: 'https://glowante.com/privacy-policy',
              ),
            ),
          );
        },
      ),
      ProfileMenuItemData(
        icon: Icons.policy_outlined,
        label: context.t('Terms & Conditions'),
        subtitle: context.t('Service agreements'),
        onTap: () {
          _logProfile('open_terms_conditions');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WebDocScreen(
                title: translateText('Terms & Conditions'),
                url: 'https://glowante.com/terms-of-services',
              ),
            ),
          );
        },
      ),
    ];

    return SharedProfileScreen(
      userName: userName?.trim().isNotEmpty == true ? userName! : '',
      phoneNumber: phoneNumber ?? '',
      currentLanguageCode: langListener.currentLang,
      onLanguageChanged: _changeLanguage,
      onRefresh: _loadUserData,
      roleLabel: context.t('Salon Owner'),
      topSections: const <Widget>[],
      menuItems: menuItems,
      onLogout: () => _showLogoutModal(context),
      onDeleteAccount: () => _showDeleteAccountDialog(context),
    );
  }
}

class _AccountSecurityScreen extends StatelessWidget {
  const _AccountSecurityScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title: context.t('Account Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SecurityCard(
            icon: Icons.lock_outline_rounded,
            title: context.t('Password'),
            subtitle: context.t('Password management will be available soon.'),
          ),
          const SizedBox(height: 12),
          _SecurityCard(
            icon: Icons.verified_user_outlined,
            title: context.t('Two-factor authentication'),
            subtitle: context.t('2FA settings will be available soon.'),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF3E8D1),
            child: Icon(
              icon,
              color: const Color(0xFF8B6500),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2D2926),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF756A61),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
