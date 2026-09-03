import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'complete_profile_shared.dart';
import 'complete_profile_step2_screen.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../widgets/app_loader.dart';
import '../widgets/multi_step_flow_header.dart';

Map<String, dynamic> _profileDetailPayload(dynamic response) {
  if (response is! Map) return const <String, dynamic>{};

  final root = Map<String, dynamic>.from(response);
  final data = root['data'];
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  root.removeWhere(
    (key, _) => key == 'success' || key == 'message' || key == 'error',
  );
  return root;
}

Map<String, dynamic> _profileMemberFromDetail(dynamic response) {
  final payload = _profileDetailPayload(response);
  if (payload.isEmpty) return payload;

  final profile = payload['profile'];
  final user = payload['user'];
  final member = profile is Map
      ? Map<String, dynamic>.from(profile)
      : user is Map
          ? Map<String, dynamic>.from(user)
          : Map<String, dynamic>.from(payload);

  for (final key in const [
    'roles',
    'branches',
    'userBranches',
    'services',
    'schedules',
    'markedOffDays',
    'branchServiceIds',
    'userBranchServices',
    'allowOnlineBooking',
    'joiningDate',
    'leavingDate',
    'experience',
    'careerStartDate',
    'careerExperienceYears',
    'profilePictureUrl',
    'avatarUrl',
    'photoUrl',
  ]) {
    final value = payload[key];
    if (value != null) {
      member[key] = value;
    }
  }

  return member;
}

Map<String, dynamic> _mergeProfileMaps(
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
) {
  final merged = Map<String, dynamic>.from(base);
  overlay.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    merged[key] = value;
  });
  return merged;
}

const List<FlowStepItem> _completeProfileSteps = [
  FlowStepItem(
      stepNumber: 1, label: 'Basic Info', icon: Icons.person_outline_rounded),
  FlowStepItem(
      stepNumber: 2, label: 'Career', icon: Icons.work_outline_rounded),
  FlowStepItem(
      stepNumber: 3, label: 'Specialities', icon: Icons.star_border_rounded),
  FlowStepItem(stepNumber: 4, label: 'Address', icon: Icons.place_outlined),
];

/// salon_team_part_2.md — profile completion (write), as a 4-step flow
/// matching AssignUser's pattern: one pushed screen per step sharing
/// MultiStepFlowHeader, a mutable CompleteProfileDraft carried forward by
/// reference, and a final popUntil-to-root + pop(true) on save (see
/// team_online_availability_screen.dart's assign flow for the same
/// pattern). Every writable field is fill-missing-only — a field the
/// server already has a value for is rendered locked on every step, never
/// editable, since a populated field can never be overwritten by a salon
/// actor.
class CompleteTeamMemberProfileScreen extends StatefulWidget {
  const CompleteTeamMemberProfileScreen({
    super.key,
    required this.salonId,
    required this.userId,
    this.branchId,
    this.initialMember,
  });

  final int salonId;
  final int userId;
  final int? branchId;
  final Map<String, dynamic>? initialMember;

  @override
  State<CompleteTeamMemberProfileScreen> createState() =>
      _CompleteTeamMemberProfileScreenState();
}

class _CompleteTeamMemberProfileScreenState
    extends State<CompleteTeamMemberProfileScreen> {
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  String? _loadError;
  CompleteProfileDraft? _draft;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final initialProfile =
          Map<String, dynamic>.from(widget.initialMember ?? {});
      final results = await Future.wait([
        ApiService().getTeamMemberDetailV2(widget.salonId, widget.userId),
        ApiService().getRolesAndSpecializations(),
      ]);
      final detailResponse = results[0];
      final rolesResponse = results[1];

      final detailData = detailResponse['data'];
      // TeamMemberDetailResponse = { profile, roles, branches, services } —
      // the editable profile fields are nested under `profile`, not the
      // top-level data object.
      if (detailResponse['success'] != true ||
          detailData is! Map ||
          detailData['profile'] is! Map) {
        setState(() {
          _loadError = extractMessage(
            detailResponse,
            fallback: 'Unable to load this team member\'s profile',
          );
          _isLoading = false;
        });
        return;
      }

      var profile = _mergeProfileMaps(
        initialProfile,
        Map<String, dynamic>.from(detailData['profile'] as Map),
      );

      if (widget.branchId != null) {
        try {
          final branchResponse = await ApiService.getTeamMemberDetails(
              widget.branchId!, widget.userId);
          profile = _mergeProfileMaps(
            profile,
            _profileMemberFromDetail(branchResponse),
          );
        } catch (_) {
          // Keep the salon profile if the branch detail endpoint fails.
        }
      }

      final rawSpecialities =
          rolesResponse['specialities'] ?? rolesResponse['specializations'];
      final specialityOptions = rawSpecialities is List
          ? rawSpecialities
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      final draft = CompleteProfileDraft(
        salonId: widget.salonId,
        userId: widget.userId,
        profile: profile,
        specialityOptions: specialityOptions,
      )..prefillFromProfile();
      setState(() {
        _draft = draft;
        _isLoading = false;
      });
      _firstNameCtrl.text = draft.firstName;
      _lastNameCtrl.text = draft.lastName;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = extractErrorMessage(
          e,
          fallback: 'Unable to load this team member\'s profile',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final draft = _draft;
    if (draft == null || draft.hasAvatar || _isUploadingAvatar) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await ApiService().uploadImage(File(picked.path));
      if (url == null || url.trim().isEmpty) {
        Fluttertoast.showToast(msg: translateText('Unable to upload photo'));
        return;
      }
      final response = await ApiService().patchTeamMemberAvatar(
        widget.salonId,
        widget.userId,
        url.trim(),
      );
      if (!mounted) return;
      if (response['success'] == true) {
        Fluttertoast.showToast(msg: translateText('Photo updated'));
        setState(() {
          draft.profile['profilePictureUrl'] = url.trim();
        });
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(response, fallback: 'Unable to update photo'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(e, fallback: 'Unable to update photo'),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _onContinue() {
    final draft = _draft;
    if (draft == null) return;
    if (!draft.hasFirstName && _firstNameCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: translateText('First name is required'));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    draft.firstName = _firstNameCtrl.text.trim();
    draft.lastName = _lastNameCtrl.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfileStep2Screen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      backgroundColor: cpSurface,
      appBar: buildProfileSubpageAppBar(title: 'Complete Profile'),
      body: _isLoading
          ? AppLoader.page()
          : _loadError != null
              ? CpErrorState(message: _loadError!, onRetry: _loadData)
              : _buildForm(context, draft!),
      bottomNavigationBar: (_isLoading || _loadError != null)
          ? null
          : CpBottomButton(
              label: translateText('Continue'),
              isBusy: false,
              onPressed: _onContinue,
            ),
    );
  }

  Widget _buildForm(BuildContext context, CompleteProfileDraft draft) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        MultiStepFlowHeader(
          currentStep: 1,
          useIcons: true,
          steps: _completeProfileSteps,
        ),
        const SizedBox(height: 20),
        const CpStepHeading(
          title: 'Basic Information',
          subtitle: 'Confirm this team member\'s name, photo, and gender.',
        ),
        if (draft.profile['isProfileComplete'] != true) ...[
          const SizedBox(height: 14),
          _MissingForActiveBanner(missing: draft.missingForActiveStatus()),
        ],
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              _buildAvatar(draft),
              const SizedBox(height: 8),
              Text(
                draft.hasAvatar
                    ? translateText('Photo added')
                    : translateText('Tap to add a photo'),
                style: const TextStyle(
                  color: cpMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CpSectionCard(
          title: translateText('Name'),
          icon: Icons.badge_outlined,
          children: [
            CpLockableField(
              label: translateText('First name'),
              isLocked: draft.hasFirstName,
              lockedValue: draft.profile['firstName']?.toString(),
              child: TextFormField(
                controller: _firstNameCtrl,
                maxLength: 50,
                decoration:
                    cpInputDecoration(translateText('First name')).copyWith(
                  counterText: '',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: cpMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CpLockableField(
              label: translateText('Last name'),
              isLocked: draft.hasLastName,
              lockedValue: draft.profile['lastName']?.toString(),
              child: TextFormField(
                controller: _lastNameCtrl,
                maxLength: 50,
                decoration:
                    cpInputDecoration(translateText('Last name')).copyWith(
                  counterText: '',
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: cpMuted),
                ),
              ),
            ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: translateText('Gender'),
          icon: Icons.wc_rounded,
          children: [
            CpLockableField(
              label: translateText('Gender'),
              isLocked: draft.hasGender,
              lockedValue: draft.profile['gender']?.toString(),
              child: Row(
                children: [
                  Icons.male_rounded,
                  Icons.female_rounded,
                  Icons.transgender_rounded,
                ].asMap().entries.map((entry) {
                  const options = ['male', 'female', 'other'];
                  final option = options[entry.key];
                  final selected = draft.gender == option;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: entry.key < 2 ? 8 : 0),
                      child: InkWell(
                        onTap: () => setState(() => draft.gender = option),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? cpAccentLight : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? cpAccent : cpBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(entry.value,
                                  size: 18,
                                  color: selected ? cpAccent : cpMuted),
                              const SizedBox(height: 4),
                              Text(
                                translateText(
                                  option[0].toUpperCase() + option.substring(1),
                                ),
                                style: TextStyle(
                                  color: selected ? cpAccent : cpMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(CompleteProfileDraft draft) {
    final imageUrl =
        (draft.profile['profilePictureUrl'] ?? '').toString().trim();
    return GestureDetector(
      onTap: draft.hasAvatar ? null : _pickAndUploadAvatar,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: cpAccent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              shape: BoxShape.circle,
              border: Border.all(color: cpAccent, width: 2),
              color: cpAccentLight,
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploadingAvatar
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: cpAccent,
                          size: 40,
                        ),
                      )
                    : const Icon(Icons.person, color: cpAccent, size: 40),
          ),
          if (!draft.hasAvatar)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: cpAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Spells out updated_3 §5.4's exact isProfileComplete formula so the salon
// can see why this member is still Setup Required even after every field
// it can fill has been filled — most commonly, phone/email verification,
// which is the member's own responsibility and outside the salon's reach.
class _MissingForActiveBanner extends StatelessWidget {
  const _MissingForActiveBanner({required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    if (missing.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C774)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                translateText('Still needed for Active status'),
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...missing.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '•  $item',
                style: const TextStyle(color: Color(0xFF8A5A0F), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
