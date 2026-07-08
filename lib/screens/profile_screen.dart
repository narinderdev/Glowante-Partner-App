import 'package:bloc_onboarding/bloc/category/category_cubit.dart';
import 'package:bloc_onboarding/bloc/salon/salon_list_cubit.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/profile/widgets/shared_profile_screen.dart';
import '../services/auth_session_manager.dart';
import '../services/language_listener.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/aws_s3_uploader.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../utils/colors.dart';
import 'add_bank_detail.dart';
import 'login_screen.dart';
import 'web_doc_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  String? userName;
  String? phoneNumber;
  String? profilePictureUrl;
  bool _isUploadingProfilePicture = false;

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
      final firstName = _readStoredValue(prefs, const [
        'firstName',
        'first_name',
      ]);
      final lastName = _readStoredValue(prefs, const [
        'lastName',
        'last_name',
      ]);
      userName = '$firstName $lastName'.trim();
      phoneNumber = _readStoredValue(prefs, const ['phone_number']);
      profilePictureUrl = _readStoredValue(prefs, const [
        'profilePictureUrl',
        'profile_picture_url',
        'profileImage',
        'profile_image',
        'imageUrl',
      ]);
    });
  }

  String _readStoredValue(
    SharedPreferences prefs,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = prefs.getString(key)?.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Future<void> _showProfilePhotoSourceModal() async {
    FocusScope.of(context).unfocus();

    final source = await showDialog<ImageSource>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),
                Text(
                  translateText('Add photo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F1B18),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translateText('Choose from gallery or take a new photo.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F665E),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(translateText('Take from camera')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(translateText('Choose from gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.starColor,
                    side: BorderSide(color: AppColors.starColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || source == null) {
      return;
    }

    await _uploadProfilePhoto(source);
  }

  Future<void> _uploadProfilePhoto(ImageSource source) async {
    if (_isUploadingProfilePicture) return;

    final token = await apiService.getAuthToken();
    if (token.isEmpty) {
      Fluttertoast.showToast(
        msg: translateText('Session expired. Please log in again.'),
      );
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (!mounted || picked == null) return;

      setState(() => _isUploadingProfilePicture = true);

      final prefs = await SharedPreferences.getInstance();
      final firstName =
          _readStoredValue(prefs, const ['firstName', 'first_name']);
      final lastName = _readStoredValue(prefs, const ['lastName', 'last_name']);
      final currentEmail = _readStoredValue(prefs, const ['email']);
      final uploaded = await AwsS3Uploader()
          .uploadImageResult(picked)
          .timeout(const Duration(minutes: 2), onTimeout: () => null);
      final uploadedUrl = uploaded?.cdnUrl ?? uploaded?.publicUrl;

      if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: translateText('Failed to upload profile photo.'),
        );
        return;
      }

      final response = await apiService.updateUserProfileDetails(
        firstName,
        lastName,
        currentEmail,
        token,
        profilePictureUrl: uploadedUrl,
      );

      final responseData = response['data'];
      String updatedProfileUrl = uploadedUrl;
      if (responseData is Map) {
        final map = Map<String, dynamic>.from(responseData);
        final responseImage = _readProfilePictureUrlFromMap(map);
        if (responseImage.isNotEmpty) {
          updatedProfileUrl = responseImage;
        }
      }

      final updatedPrefs = await SharedPreferences.getInstance();
      await _storeProfilePictureUrl(updatedPrefs, updatedProfileUrl);

      if (!mounted) return;
      setState(() {
        profilePictureUrl = updatedProfileUrl;
      });

      Fluttertoast.showToast(
        msg: translateText('Profile photo updated successfully.'),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('Profile photo upload failed: $error');
      final message = extractErrorMessage(error, fallback: '').trim();
      if (message.isEmpty) {
        return;
      }
      Fluttertoast.showToast(
        msg: message,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePicture = false);
      }
    }
  }

  String _readProfilePictureUrlFromMap(Map<String, dynamic> map) {
    const keys = [
      'profilePictureUrl',
      'profile_picture_url',
      'profileImage',
      'profile_image',
      'imageUrl',
    ];
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  Future<void> _storeProfilePictureUrl(
    SharedPreferences prefs,
    String value,
  ) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }

    await prefs.setString('profilePictureUrl', normalized);
    await prefs.setString('profile_picture_url', normalized);
    await prefs.setString('profileImage', normalized);
    await prefs.setString('profile_image', normalized);
    await prefs.setString('imageUrl', normalized);
  }

  void _changeLanguage(String langCode) {
    _logProfile('language_changed', details: langCode);
    final langListener = Provider.of<LanguageListener>(context, listen: false);
    langListener.changeLanguage(langCode);
  }

  void _showLogoutModal(BuildContext context) {
    FocusScope.of(context).unfocus();
    final logoutTitle = translateText('Logout');
    final logoutMessage = translateText('Are you sure you want to log out?');
    final cancelLabel = translateText('Cancel');
    final confirmLogoutLabel = translateText('Yes, log out');
    final failureText = translateText('Logout request failed on the server.');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                Fluttertoast.showToast(msg: failureText);
              }

              await AuthSessionManager.instance.forceLogout(
                reason: success ? 'user_logout' : 'user_logout_failed',
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                logoutTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.starColor,
                ),
              ),
              content: Text(
                logoutMessage,
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: isLoggingOut ? null : () => Navigator.pop(ctx),
                  child: Text(cancelLabel),
                ),
                ElevatedButton(
                  onPressed: isLoggingOut ? null : handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
              ],
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
                Fluttertoast.showToast(msg: deleteFailureText);
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
        icon: Icons.account_balance_outlined,
        label: context.t('Bank Details'),
        subtitle: context.t('Payout account for salon earnings'),
        onTap: () {
          _logProfile('open_bank_details');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBankDetailScreen()),
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

    final profileScreen = SharedProfileScreen(
      userName: userName?.trim().isNotEmpty == true ? userName! : '',
      phoneNumber: phoneNumber ?? '',
      currentLanguageCode: langListener.currentLang,
      onLanguageChanged: _changeLanguage,
      onRefresh: _loadUserData,
      roleLabel: context.t('Salon Owner'),
      profileImageUrl: profilePictureUrl,
      onEditProfilePicture:
          _isUploadingProfilePicture ? null : _showProfilePhotoSourceModal,
      topSections: const <Widget>[],
      menuItems: menuItems,
      onLogout: () => _showLogoutModal(context),
      onDeleteAccount: () => _showDeleteAccountDialog(context),
    );

    if (!_isUploadingProfilePicture) {
      return profileScreen;
    }

    return Stack(
      children: [
        profileScreen,
        const Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: Color(0x66000000),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: _ProfileUploadOverlay(
              title: translateText('Updating profile photo'),
              subtitle: translateText('Uploading and saving your changes'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileUploadOverlay extends StatelessWidget {
  const _ProfileUploadOverlay({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DED6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFC19A6B), Color(0xFFD7B37A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26C19A6B),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Color(0xFF6F665E),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              minHeight: 7,
              backgroundColor: Color(0xFFF1EBE6),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please keep this screen open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF8A8179),
            ),
          ),
        ],
      ),
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
