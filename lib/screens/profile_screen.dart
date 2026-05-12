import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/compensation/profile_compensation_screen.dart';
import '../features/profile/widgets/shared_profile_screen.dart';
import '../services/auth_session_manager.dart';
import '../services/language_listener.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import 'SalonAbout.dart';
import 'SalonReviews.dart';
import 'login_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_branch_clients_screen.dart';
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

    return SharedProfileScreen(
      userName: userName?.trim().isNotEmpty == true ? userName! : '',
      phoneNumber: phoneNumber ?? '',
      currentLanguageCode: langListener.currentLang,
      onLanguageChanged: _changeLanguage,
      onRefresh: _loadUserData,
      topSections: [
        _ProfileCompensationEntry(
          onOpenPayroll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileCompensationScreen(
                  initialModule: CompensationModule.payroll,
                ),
              ),
            );
          },
          onOpenCommission: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileCompensationScreen(
                  initialModule: CompensationModule.commission,
                ),
              ),
            );
          },
        ),
      ],
      menuItems: [
        ProfileMenuItemData(
          icon: Icons.dashboard_outlined,
          label: context.t('Dashboard'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OwnerDashboardScreen(),
              ),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.groups_outlined,
          label: context.t('Clients'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OwnerBranchClientsScreen(),
              ),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.rate_review_outlined,
          label: context.t('Reviews'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonReviews()),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.info_outline,
          label: context.t('About Salon'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonAbout()),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.privacy_tip_outlined,
          label: context.t('Privacy Policy'),
          onTap: () {
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
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.policy_outlined,
          label: context.t('Terms & Conditions'),
          onTap: () {
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
          showLeftAccent: true,
        ),
      ],
      onLogout: () => _showLogoutModal(context),
      onDeleteAccount: () => _showDeleteAccountDialog(context),
    );
  }
}

class _ProfileCompensationEntry extends StatelessWidget {
  const _ProfileCompensationEntry({
    required this.onOpenPayroll,
    required this.onOpenCommission,
  });

  final VoidCallback onOpenPayroll;
  final VoidCallback onOpenCommission;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileEntryButton(
          icon: Icons.payments_outlined,
          label: context.t('Payroll'),
          onTap: onOpenPayroll,
        ),
        const SizedBox(height: 12),
        _ProfileEntryButton(
          icon: Icons.tune_rounded,
          label: context.t('Commission'),
          onTap: onOpenCommission,
        ),
      ],
    );
  }
}

class _ProfileEntryButton extends StatelessWidget {
  const _ProfileEntryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              left: BorderSide(
                color: Color(0xFFC19A6B),
                width: 4,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: const Color(0xFF78716C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF78716C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
