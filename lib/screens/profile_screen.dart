import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/compensation/profile_compensation_screen.dart';
import '../features/profile/operations/owner_profile_operations_screen.dart';
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

  void _openDashboard() {
    _logProfile('open_dashboard');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerDashboardScreen(),
      ),
    );
  }

  void _showProfilePlaceholder(String label) {
    _logProfile('open_placeholder', details: label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('$label is coming soon'))),
    );
  }

  void _openClients() {
    _logProfile('open_clients');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerBranchClientsScreen(),
      ),
    );
  }

  void _openCommission() {
    _logProfile('open_commission');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.commission,
        ),
      ),
    );
  }

  void _openInventory() {
    _logProfile('open_inventory');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerProfileOperationsScreen(
          initialModule: OwnerOperationsModule.inventory,
        ),
      ),
    );
  }

  void _openPayroll() {
    _logProfile('open_payroll');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.payroll,
        ),
      ),
    );
  }

  void _openAdvance() {
    _logProfile('open_advance');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.advance,
        ),
      ),
    );
  }

  void _openAttendance() {
    _logProfile('open_attendance');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.attendance,
        ),
      ),
    );
  }

  void _openLeaves() {
    _logProfile('open_leaves');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.leaves,
        ),
      ),
    );
  }

  void _openHolidaysCalendar() {
    _logProfile('open_holidays_calendar');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileCompensationScreen(
          initialModule: CompensationModule.holidays,
        ),
      ),
    );
  }

  void _openVendor() {
    _logProfile('open_vendor');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OwnerProfileOperationsScreen(
          initialModule: OwnerOperationsModule.vendor,
        ),
      ),
    );
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
      topSections: const <Widget>[],
      menuItems: [
        ProfileMenuItemData(
          icon: Icons.info_outline,
          label: context.t('About Salon'),
          onTap: () {
            _logProfile('open_about_salon');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonAbout()),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.groups_outlined,
          label: context.t('Clients'),
          onTap: _openClients,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.tune_rounded,
          label: context.t('Commission'),
          onTap: _openCommission,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.insert_chart_outlined_rounded,
          label: context.t('Reports'),
          onTap: _openDashboard,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.bar_chart_rounded,
          label: context.t('Sales & Reports'),
          showLeftAccent: true,
          children: [
            ProfileSubMenuItemData(
              label: context.t('Revenue & Sales'),
            ),
            ProfileSubMenuItemData(
              label: context.t('Staff Performance'),
              onTap: () => _showProfilePlaceholder('Staff Performance'),
            ),
            ProfileSubMenuItemData(
              label: context.t('Operations'),
              onTap: () => _showProfilePlaceholder('Operations'),
            ),
          ],
        ),
        ProfileMenuItemData(
          icon: Icons.inventory_2_outlined,
          label: context.t('Inventory'),
          onTap: _openInventory,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.payments_outlined,
          label: context.t('Payroll'),
          onTap: _openPayroll,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.account_balance_wallet_outlined,
          label: context.t('Advance'),
          onTap: _openAdvance,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.event_available_outlined,
          label: context.t('Attendance'),
          onTap: _openAttendance,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.beach_access_outlined,
          label: context.t('Leaves'),
          onTap: _openLeaves,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.calendar_month_outlined,
          label: context.t('Holidays Calendar'),
          onTap: _openHolidaysCalendar,
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.privacy_tip_outlined,
          label: context.t('Privacy Policy'),
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
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.rate_review_outlined,
          label: context.t('Reviews'),
          onTap: () {
            _logProfile('open_reviews');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalonReviews()),
            );
          },
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.policy_outlined,
          label: context.t('Terms & Conditions'),
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
          showLeftAccent: true,
        ),
        ProfileMenuItemData(
          icon: Icons.badge_outlined,
          label: context.t('Vendor'),
          onTap: _openVendor,
          showLeftAccent: true,
        ),
      ],
      onLogout: () => _showLogoutModal(context),
      onDeleteAccount: () => _showDeleteAccountDialog(context),
    );
  }
}
