import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'add_location_screen.dart';
import 'complete_profile_flow_constants.dart';
import 'complete_profile_shared.dart';
import 'team_branch_setup_screen.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/error_parser.dart';
import '../widgets/app_loader.dart';

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
    'userSalons',
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

/// One consolidated "Personal Information" screen (avatar, name, gender,
/// address, bio, career start date, specialities), replacing what used to
/// be four separate pushed screens — matches the web admin's single-step
/// layout. Two independent modes control what happens around it:
///
/// - [allowFullEdit] false (default): fill-missing-only — a field the
///   server already has a value for is locked, and only newly-filled
///   fields are sent. This is onboarding: don't let a salon actor
///   overwrite something already correct. True: nothing is locked, and
///   whatever is currently in each field gets sent — this is the
///   standalone "Edit" action on an already-active member.
/// - [chainIntoAssignFlow] true: saving continues straight into
///   TeamBranchSetupScreen (open branch dropdown, chained into
///   TeamMemberCompensationSetupStep on success) instead of returning to
///   Team Members — the Setup Required "Assign User" action, which is
///   Personal Information → Branch Setup → Employment Details as one flow.
class TeamMemberPersonalInfoScreen extends StatefulWidget {
  const TeamMemberPersonalInfoScreen({
    super.key,
    required this.salonId,
    required this.userId,
    this.branchId,
    this.initialMember,
    this.salons = const <Map<String, dynamic>>[],
    this.allowFullEdit = false,
    this.chainIntoAssignFlow = false,
    this.chainIntoBranchSetup = false,
    this.branchSetupLocked = true,
  });

  final int salonId;
  final int userId;
  final int? branchId;
  final Map<String, dynamic>? initialMember;
  final List<Map<String, dynamic>> salons;
  final bool allowFullEdit;
  final bool chainIntoAssignFlow;
  // Active member "Edit" or "Assign User" — after saving, continue into
  // TeamBranchSetupScreen instead of just popping.
  final bool chainIntoBranchSetup;
  // Only relevant when chainIntoBranchSetup is true. True (Edit): Branch
  // Setup locks to `branchId`, their current branch. False (Assign User):
  // Branch Setup's dropdown is open to pick any available branch.
  final bool branchSetupLocked;

  @override
  State<TeamMemberPersonalInfoScreen> createState() =>
      _TeamMemberPersonalInfoScreenState();
}

class _TeamMemberPersonalInfoScreenState
    extends State<TeamMemberPersonalInfoScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _loadError;
  CompleteProfileDraft? _draft;
  bool _showValidationErrors = false;
  // Captured from TeamBranchSetupScreen's back-arrow result when the actor
  // backs out of it before saving, so re-entering it (Save & Continue here
  // again) restores the in-progress branch/roles/services/etc. selection
  // instead of starting over.
  Map<String, dynamic>? _branchSetupDraft;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bioCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
    _line1Ctrl.dispose();
    _cityCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  bool get _bioHasError {
    final draft = _draft;
    return _showValidationErrors &&
        draft != null &&
        !draft.hasBio &&
        _bioCtrl.text.trim().isEmpty;
  }

  bool get _genderHasError {
    final draft = _draft;
    return _showValidationErrors &&
        draft != null &&
        !draft.hasGender &&
        draft.gender == null;
  }

  bool get _careerStartDateHasError {
    final draft = _draft;
    return _showValidationErrors &&
        draft != null &&
        !draft.hasCareerStartDate &&
        draft.careerStartDate == null;
  }

  // Mirrors CompleteProfileDraft.addressCompletionError()'s logic but reads
  // the live controllers directly rather than draft's own line1/city/etc.
  // fields, which only get synced from them at submit time
  // (_syncDraftFromControllers) — this needs to reflect what's on screen
  // right now, before another submit attempt.
  String? get _addressError {
    final draft = _draft;
    if (!_showValidationErrors || draft == null || draft.hasAddress) {
      return null;
    }
    final missing = <String>[];
    if (_line1Ctrl.text.trim().isEmpty) {
      missing.add(translateText('Address line 1'));
    }
    if (_cityCtrl.text.trim().isEmpty && _villageCtrl.text.trim().isEmpty) {
      missing.add(translateText('City or Village'));
    }
    if (_stateCtrl.text.trim().isEmpty) missing.add(translateText('State'));
    if (_countryCtrl.text.trim().isEmpty) {
      missing.add(translateText('Country'));
    }
    if (_postalCodeCtrl.text.trim().isEmpty) {
      missing.add(translateText('Postal code'));
    }
    if (missing.isEmpty) return null;
    return translateText(
      'Address is missing: {fields}',
      params: {'fields': missing.join(', ')},
    );
  }

  bool get _specialitiesHasError {
    final draft = _draft;
    return _showValidationErrors &&
        draft != null &&
        draft.specialityCodes.isEmpty &&
        draft.specialityOptions.isNotEmpty;
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
            widget.branchId!,
            widget.userId,
          );
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
        allowFullEdit: widget.allowFullEdit,
      )..prefillFromProfile();
      setState(() {
        _draft = draft;
        _isLoading = false;
      });
      _firstNameCtrl.text = draft.firstName;
      _lastNameCtrl.text = draft.lastName;
      _bioCtrl.text = draft.bio;
      _line1Ctrl.text = draft.line1;
      _cityCtrl.text = draft.city;
      _villageCtrl.text = draft.village;
      _districtCtrl.text = draft.district;
      _stateCtrl.text = draft.state;
      _countryCtrl.text = draft.country;
      _postalCodeCtrl.text = draft.postalCode;
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
    if (draft == null || (draft.hasAvatar && !widget.allowFullEdit)) return;
    if (_isUploadingAvatar) return;
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
        final updatedProfile = _profileMemberFromDetail(response);
        final updatedUrl =
            (updatedProfile['profilePictureUrl'] ?? url.trim()).toString();
        Fluttertoast.showToast(msg: translateText('Photo updated'));
        setState(() {
          draft.profile['profilePictureUrl'] = updatedUrl.trim();
          draft.hasSavedChanges = true;
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

  Future<void> _pickCareerStartDate() async {
    final draft = _draft;
    if (draft == null || draft.hasCareerStartDate) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latestSelectableDate = today.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.careerStartDate ?? latestSelectableDate,
      firstDate: DateTime(now.year - 60),
      lastDate: latestSelectableDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: cpAccent,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => draft.careerStartDate = picked);
    }
  }

  Future<void> _pickSpecialities(CompleteProfileDraft draft) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final temp = Set<String>.from(draft.specialityCodes);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translateText('Select Specialities'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: draft.specialityOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final option = draft.specialityOptions[i];
                          final code = (option['code'] ?? option['name'] ?? '')
                              .toString();
                          final label = (option['name'] ?? option['code'] ?? '')
                              .toString();
                          final checked = temp.contains(code);
                          return CheckboxListTile(
                            value: checked,
                            activeColor: cpAccent,
                            checkColor: Colors.white,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(label),
                            onChanged: (v) {
                              if (v == true && temp.length >= 10) {
                                Fluttertoast.showToast(
                                  msg: translateText(
                                    'You can select up to 10 specialities',
                                  ),
                                );
                                return;
                              }
                              setSheetState(() {
                                if (v == true) {
                                  temp.add(code);
                                } else {
                                  temp.remove(code);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cpAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(translateText('Done')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        draft.specialityCodes
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _chooseAddressLocation() async {
    final draft = _draft;
    if (draft == null || draft.hasAddress) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLocationScreen(
          initialCompleteAddress:
              _line1Ctrl.text.trim().isEmpty ? null : _line1Ctrl.text.trim(),
        ),
      ),
    );
    if (!mounted || result == null) return;

    final completeAddress =
        (result['completeAddress'] as String?)?.trim() ?? '';
    final baseCompleteAddress =
        (result['baseCompleteAddress'] as String?)?.trim() ?? '';
    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();
    String resultText(String key) => (result[key] as String?)?.trim() ?? '';

    setState(() {
      _line1Ctrl.text = baseCompleteAddress.isNotEmpty
          ? baseCompleteAddress
          : completeAddress;
      _cityCtrl.text = resultText('city');
      _villageCtrl.clear();
      _districtCtrl.text = resultText('district');
      _stateCtrl.text = resultText('state');
      _countryCtrl.text = resultText('country');
      _postalCodeCtrl.text = resultText('postalCode');
      draft.latitude = latitude;
      draft.longitude = longitude;
    });

    if (latitude != null && longitude != null) {
      try {
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (!mounted || placemarks.isEmpty) return;
        final place = placemarks.first;
        setState(() {
          _cityCtrl.text = (place.locality ?? '').trim().isNotEmpty
              ? (place.locality ?? '').trim()
              : _cityCtrl.text;
          _districtCtrl.text =
              (place.subAdministrativeArea ?? '').trim().isNotEmpty
                  ? (place.subAdministrativeArea ?? '').trim()
                  : _districtCtrl.text;
          _stateCtrl.text = (place.administrativeArea ?? '').trim().isNotEmpty
              ? (place.administrativeArea ?? '').trim()
              : _stateCtrl.text;
          _countryCtrl.text = (place.country ?? '').trim().isNotEmpty
              ? (place.country ?? '').trim()
              : _countryCtrl.text;
          _postalCodeCtrl.text = (place.postalCode ?? '').trim().isNotEmpty
              ? (place.postalCode ?? '').trim()
              : _postalCodeCtrl.text;
        });
      } catch (e) {
        debugPrint('Reverse geocoding failed: $e');
      }
    }
  }

  void _syncDraftFromControllers(CompleteProfileDraft draft) {
    draft.firstName = _firstNameCtrl.text.trim();
    draft.lastName = _lastNameCtrl.text.trim();
    draft.bio = _bioCtrl.text.trim();
    draft.line1 = _line1Ctrl.text.trim();
    draft.city = _cityCtrl.text.trim();
    draft.village = _villageCtrl.text.trim();
    draft.district = _districtCtrl.text.trim();
    draft.state = _stateCtrl.text.trim();
    draft.country = _countryCtrl.text.trim();
    draft.postalCode = _postalCodeCtrl.text.trim();
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _showValidationErrors = true);

    if (!draft.hasFirstName && _firstNameCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: translateText('First name is required'));
      return;
    }
    if (_genderHasError) {
      Fluttertoast.showToast(msg: translateText('Gender is required'));
      return;
    }
    if (_bioHasError) {
      Fluttertoast.showToast(msg: translateText('Bio is required'));
      return;
    }
    if (_careerStartDateHasError) {
      Fluttertoast.showToast(
        msg: translateText('Career start date is required'),
      );
      return;
    }
    // Skipped only when there's genuinely nothing to pick from — otherwise
    // the "No specialities available" state would be unsaveable.
    if (draft.specialityCodes.isEmpty && draft.specialityOptions.isNotEmpty) {
      Fluttertoast.showToast(
        msg: translateText('Select at least one speciality'),
      );
      return;
    }

    _syncDraftFromControllers(draft);

    final addressError = draft.addressCompletionError();
    if (addressError != null) {
      Fluttertoast.showToast(msg: addressError);
      return;
    }

    final fields = draft.buildPatchFields();
    if (fields.isEmpty) {
      if (!draft.hasSavedChanges &&
          !widget.chainIntoAssignFlow &&
          !widget.chainIntoBranchSetup) {
        Fluttertoast.showToast(msg: translateText('Nothing new to save'));
        return;
      }
      await _afterSaved(draft);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await ApiService().patchTeamMemberProfile(
        draft.salonId,
        draft.userId,
        fields,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        draft.profile.addAll(fields);
        Fluttertoast.showToast(msg: translateText('Profile updated'));
        await _afterSaved(draft);
      } else {
        Fluttertoast.showToast(
          msg: extractMessage(response, fallback: 'Unable to update profile'),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: extractErrorMessage(e, fallback: 'Unable to update profile'),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _afterSaved(CompleteProfileDraft draft) async {
    if (widget.chainIntoBranchSetup) {
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => TeamBranchSetupScreen(
            salonId: draft.salonId,
            userId: draft.userId,
            member: draft.profile,
            salons: widget.salons,
            lockedBranchId: widget.branchSetupLocked ? widget.branchId : null,
            initialDraft: _branchSetupDraft,
          ),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        _returnToTeamMembersWithRefresh();
      } else if (result is Map<String, dynamic>) {
        // Backed out before saving — keep the in-progress selection so it's
        // restored if they come back to Branch Setup.
        _branchSetupDraft = result;
      }
      // Otherwise stay here — the actor backed out of Branch Setup, they
      // can pick "Save & Continue" again to retry it.
      return;
    }

    if (!widget.chainIntoAssignFlow) {
      // Neither chain flag set — this is the standalone quick-edit entry
      // point (View Member's pencil icon), pushed directly rather than
      // through SalonTeams.dart's chain, so there's no
      // kCompleteProfileRootRouteName marker anywhere in this stack for
      // _returnToTeamMembersWithRefresh()'s popUntil to find — without one
      // it pops all the way to the very first route in the whole app
      // instead of just back to whatever pushed this screen. A plain pop
      // returns to that caller, which handles its own refresh.
      Navigator.pop(context, true);
      return;
    }

    final assigned = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => TeamBranchSetupScreen(
          salonId: draft.salonId,
          userId: draft.userId,
          member: draft.profile,
          salons: widget.salons,
          lockedBranchId: null,
          chainIntoCompensation: true,
          initialDraft: _branchSetupDraft,
        ),
      ),
    );
    if (!mounted) return;
    if (assigned == true) {
      _returnToTeamMembersWithRefresh();
    } else if (assigned is Map<String, dynamic>) {
      _branchSetupDraft = assigned;
    }
    // Otherwise the salon actor backed out of the assign flow entirely —
    // stay right here so they can pick "Save & Continue" again.
  }

  void _returnToTeamMembersWithRefresh() {
    final navigator = Navigator.of(context);
    var foundRoot = false;
    navigator.popUntil((route) {
      final isRoot = route.settings.name == kCompleteProfileRootRouteName;
      if (isRoot) foundRoot = true;
      return isRoot || route.isFirst;
    });
    if (foundRoot) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.pop(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      backgroundColor: cpSurface,
      appBar: buildProfileSubpageAppBar(title: 'Personal Information'),
      body: _isLoading
          ? AppLoader.page()
          : _loadError != null
              ? CpErrorState(message: _loadError!, onRetry: _loadData)
              : _buildForm(context, draft!),
      bottomNavigationBar: (_isLoading || _loadError != null)
          ? null
          : CpBottomButton(
              label: translateText('Save & Continue'),
              isBusy: _isSaving || _isUploadingAvatar,
              onPressed: _submit,
            ),
    );
  }

  Widget _buildForm(BuildContext context, CompleteProfileDraft draft) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildMemberSummaryCard(draft),
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
          title: translateText('Gender'),
          icon: Icons.wc_rounded,
          required: true,
          children: [
            CpLockableField(
              label: translateText('Gender'),
              isLocked: draft.hasGender,
              lockedValue: draft.profile['gender']?.toString(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          padding:
                              EdgeInsets.only(right: entry.key < 2 ? 8 : 0),
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
                                      option[0].toUpperCase() +
                                          option.substring(1),
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
                  if (_genderHasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      translateText('Gender is required'),
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: translateText('Name'),
          icon: Icons.badge_outlined,
          required: true,
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
          title: translateText('Address'),
          icon: Icons.place_outlined,
          required: true,
          children: [
            if (draft.hasAddress)
              CpLockedValueChip(
                value: [
                  draft.address['line1'],
                  draft.address['city'],
                  draft.address['state'],
                  draft.address['postalCode'],
                ]
                    .where((part) => cpIsFilled(part))
                    .map((part) => part.toString())
                    .join(', '),
              )
            else ...[
              InkWell(
                onTap: _chooseAddressLocation,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cpBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_location_alt_rounded,
                          color: cpAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _line1Ctrl.text.trim().isEmpty
                              ? translateText('Search address')
                              : _line1Ctrl.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _line1Ctrl.text.trim().isEmpty
                                ? cpMuted
                                : cpInk,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // City/village/district/state/country/postal code are all
              // captured by AddLocationScreen's geocoding when a location is
              // picked above — re-showing them as separate editable fields
              // here re-asks for data already collected. Once something's
              // been picked, show what was captured as a compact summary
              // instead; to correct it, re-tap "Search address" above and
              // pick again, rather than hand-editing each sub-field. No
              // separate "Address line 2" field either — AddLocationScreen
              // already covers house/flat no. and street/area, so line1
              // (the assembled complete address) is enough on its own.
              if ([
                _cityCtrl,
                _villageCtrl,
                _districtCtrl,
                _stateCtrl,
                _countryCtrl,
                _postalCodeCtrl,
              ].any((c) => c.text.trim().isNotEmpty)) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cpSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cpBorder),
                  ),
                  child: Text(
                    [
                      _cityCtrl.text.trim(),
                      _villageCtrl.text.trim(),
                      _districtCtrl.text.trim(),
                      _stateCtrl.text.trim(),
                      _countryCtrl.text.trim(),
                      _postalCodeCtrl.text.trim(),
                    ].where((part) => part.isNotEmpty).join(', '),
                    style: const TextStyle(color: cpInk, fontSize: 12.5),
                  ),
                ),
              ],
              if (_addressError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _addressError!,
                  style: const TextStyle(color: AppColors.red, fontSize: 11.5),
                ),
              ],
            ],
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: translateText('Bio'),
          icon: Icons.description_outlined,
          required: true,
          children: [
            CpLockableField(
              label: translateText('Bio'),
              isLocked: draft.hasBio,
              lockedValue: draft.profile['bio']?.toString(),
              child: TextFormField(
                controller: _bioCtrl,
                maxLines: 4,
                maxLength: 250,
                decoration: cpInputDecoration(
                  translateText('Tell clients a bit about this member'),
                ).copyWith(
                  errorText:
                      _bioHasError ? translateText('Bio is required') : null,
                ),
              ),
            ),
          ],
        ),
        const CpSectionDivider(),
        CpSectionCard(
          title: translateText('Career start date'),
          icon: Icons.work_outline_rounded,
          required: true,
          children: [
            CpLockableField(
              label: translateText('Career start date'),
              isLocked: draft.hasCareerStartDate,
              lockedValue: draft.profile['careerStartDate']?.toString(),
              child: InkWell(
                onTap: _pickCareerStartDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration:
                      cpInputDecoration(translateText('Select date')).copyWith(
                    prefixIcon: const Icon(Icons.calendar_today_outlined,
                        size: 16, color: cpMuted),
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: cpMuted),
                    errorText: _careerStartDateHasError
                        ? translateText('Career start date is required')
                        : null,
                  ),
                  child: Text(
                    draft.careerStartDate == null
                        ? translateText('Select date')
                        : '${draft.careerStartDate!.year}-${draft.careerStartDate!.month.toString().padLeft(2, '0')}-${draft.careerStartDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: draft.careerStartDate == null ? cpMuted : cpInk,
                    ),
                  ),
                ),
              ),
            ),
            if (cpIsFilled(draft.profile['careerExperienceYears'])) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.military_tech_outlined,
                      size: 14, color: cpAccent),
                  const SizedBox(width: 6),
                  Text(
                    translateText(
                      '{n} years of experience',
                      params: {
                        'n': '${draft.profile['careerExperienceYears']}'
                      },
                    ),
                    style: const TextStyle(
                      color: cpMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const CpSectionDivider(),
        if (draft.hasSpecialities)
          CpSectionCard(
            title: translateText('Specialities'),
            icon: Icons.star_border_rounded,
            required: true,
            children: [
              CpLockedValueChip(
                // Handles both shapes this field comes back in — {code,
                // name} objects (e.g. right after a save's own response)
                // and plain code strings (some GET responses) — a Map-only
                // filter here silently dropped every entry for the latter,
                // showing "Not set" despite specialities genuinely being
                // set.
                value: (draft.profile['specialities'] as List)
                    .map((s) => s is Map
                        ? (s['name'] ?? s['code'] ?? '').toString()
                        : s.toString())
                    .where((s) => s.isNotEmpty)
                    .join(', '),
              ),
            ],
          )
        else if (draft.specialityOptions.isEmpty)
          CpSectionCard(
            title: translateText('Specialities'),
            icon: Icons.star_border_rounded,
            required: true,
            children: [
              Text(
                translateText('No specialities available'),
                style: const TextStyle(color: cpMuted, fontSize: 12.5),
              ),
            ],
          )
        else
          CpSectionCard(
            title: translateText('Specialities'),
            icon: Icons.star_border_rounded,
            required: true,
            children: [
              InkWell(
                onTap: () => _pickSpecialities(draft),
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration:
                      cpInputDecoration(translateText('Select specialities'))
                          .copyWith(
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: cpMuted),
                    errorText: _specialitiesHasError
                        ? translateText('Select at least one speciality')
                        : null,
                  ),
                  child: Text(
                    draft.specialityCodes.isEmpty
                        ? translateText('Select specialities')
                        : translateText(
                            '{n} selected',
                            params: {'n': '${draft.specialityCodes.length}'},
                          ),
                    style: TextStyle(
                      color: draft.specialityCodes.isEmpty ? cpMuted : cpInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _profileText(
    CompleteProfileDraft draft,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = draft.profile[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  Widget _buildMemberSummaryCard(CompleteProfileDraft draft) {
    final firstName = _profileText(draft, const ['firstName']);
    final lastName = _profileText(draft, const ['lastName']);
    final fullName = _profileText(
      draft,
      const ['fullName', 'name'],
      fallback: '$firstName $lastName'.trim(),
    );
    final email = _profileText(draft, const ['email']);
    final phone = _profileText(
      draft,
      const ['fullPhoneNumber', 'phoneNumber', 'mobileNumber', 'phone'],
    );
    final isProfileComplete = draft.profile['isProfileComplete'] == true;
    final rawStatus = _profileText(draft, const ['status']);
    final status = rawStatus.isEmpty
        ? (isProfileComplete
            ? translateText('Active')
            : translateText('Setup Required'))
        : rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
    final displayName =
        fullName.isEmpty ? translateText('Team Member') : fullName;
    final initial =
        displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cpBorder),
        boxShadow: [
          BoxShadow(
            color: cpAccent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cpAccentLight,
              shape: BoxShape.circle,
              border: Border.all(color: cpAccent, width: 1.5),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: cpAccent,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cpInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isProfileComplete
                            ? const Color(0xFFE7F8EA)
                            : const Color(0xFFFFF3D5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        translateText(status),
                        style: TextStyle(
                          color: isProfileComplete
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFB45309),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          size: 14, color: cpMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: cpMuted, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.call_outlined, size: 14, color: cpMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: cpMuted, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CompleteProfileDraft draft) {
    final imageUrl =
        (draft.profile['profilePictureUrl'] ?? '').toString().trim();
    final canEditAvatar = widget.allowFullEdit || !draft.hasAvatar;
    return GestureDetector(
      onTap: canEditAvatar ? _pickAndUploadAvatar : null,
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
          if (canEditAvatar)
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
