import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colors.dart';

import '../utils/api_service.dart';

import '../screens/web_doc_screen.dart';

import '../services/auth_session_manager.dart';
import 'login_screen.dart';

import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/bloc/category/category_cubit.dart';

import '../services/language_listener.dart';

import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'SalonReviews.dart';

import 'SalonAbout.dart';

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

    setState(() {
      String firstName =
          prefs.getString('firstName') ?? prefs.getString('first_name') ?? '';

      String lastName =
          prefs.getString('lastName') ?? prefs.getString('last_name') ?? '';

      userName = (firstName + ' ' + lastName).trim();

      phoneNumber = prefs.getString('phone_number') ?? '';
    });
  }

  void _changeLanguage(String langCode) {
    final langListener = Provider.of<LanguageListener>(context, listen: false);

    langListener
        .changeLanguage(langCode); // should call notifyListeners() inside
  }

  // ---------------------- LOGOUT ----------------------

  void _showLogoutModal(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        bool isLoggingOut = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
              Future<void> _handleLogout() async {
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
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('Logout'),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                  SizedBox(height: 10),
                  Text(
                    context.t('Are you sure you want to log out?'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  SizedBox(height: 20),
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
                          child: Text(context.t('Cancel')),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoggingOut ? null : _handleLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.starColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoggingOut
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
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
    ).whenComplete(() {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  // ---------------------- DELETE ACCOUNT ----------------------

  void _showDeleteAccountDialog(BuildContext context) {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> _handleDelete() async {
              if (isDeleting) return;

              setDialogState(() => isDeleting = true);

              final success = await apiService.deleteAccountAPI();

              if (!mounted) return;

              setDialogState(() => isDeleting = false);

              if (success) {
                Navigator.pop(ctx);

                if (!mounted) return;

                context.read<SalonListCubit>().clear();
                context.read<CategoryCubit>().clear();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(context.t('Delete failed. Please try again.'))),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.t('Delete Account'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.starColor),
              ),
              content: Text(
                context.t('Are you sure you want to delete your account?'),
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text(context.t('Cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isDeleting ? null : _handleDelete,
                  child: isDeleting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(context.t('Yes, delete')),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final langListener = Provider.of<LanguageListener>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.t('Profile'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[200],
                    child:
                        Icon(Icons.person, size: 50, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12),
                  Text(
                    userName ?? '',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    phoneNumber ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Language selection

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Language'), // will rebuild automatically

                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _languageButton('en', context.t('English')),
                      SizedBox(width: 12),
                      _languageButton('hi', 'हिंदी'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Documents links

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading:
                      Icon(Icons.privacy_tip_outlined, color: Colors.black87),
                  title: Text(context.t('Privacy Policy')),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
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
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.policy_outlined, color: Colors.black87),
                  title: Text(context.t('Terms & Conditions')),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
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
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined,
                      color: Colors.black87),
                  title: Text(context.t('Reviews')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalonReviews(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined,
                      color: Colors.black87),
                  title: Text(context.t('About Salon')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalonAbout(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 30),

          // Logout & Delete

          ElevatedButton.icon(
            onPressed: () => _showLogoutModal(context),
            icon: Icon(Icons.logout),
            label: Text(context.t('Logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () => _showDeleteAccountDialog(context),
            icon: Icon(Icons.delete_forever),
            label: Text(context.t('Delete Account')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.starColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          SizedBox(height: 24),
        ],
      ),
    );
  }

  // Language selection button

  Widget _languageButton(String code, String label) {
    final langListener = Provider.of<LanguageListener>(context);

    final isSelected = langListener.currentLang == code;

    return Expanded(
      child: OutlinedButton(
        onPressed: () => _changeLanguage(code),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.starColor : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          side: BorderSide(color: AppColors.starColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
