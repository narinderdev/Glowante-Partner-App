import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'add_location_screen.dart';
import 'complete_profile_flow_constants.dart';
import 'complete_profile_shared.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../utils/api_service.dart';
import '../utils/error_parser.dart';
import '../widgets/multi_step_flow_header.dart';

const List<FlowStepItem> _steps = [
  FlowStepItem(
      stepNumber: 1, label: 'Basic Info', icon: Icons.person_outline_rounded),
  FlowStepItem(
      stepNumber: 2, label: 'Career', icon: Icons.work_outline_rounded),
  FlowStepItem(
      stepNumber: 3, label: 'Specialities', icon: Icons.star_border_rounded),
  FlowStepItem(stepNumber: 4, label: 'Address', icon: Icons.place_outlined),
];

class CompleteProfileStep4Screen extends StatefulWidget {
  const CompleteProfileStep4Screen({super.key, required this.draft});

  final CompleteProfileDraft draft;

  @override
  State<CompleteProfileStep4Screen> createState() =>
      _CompleteProfileStep4ScreenState();
}

class _CompleteProfileStep4ScreenState
    extends State<CompleteProfileStep4Screen> {
  bool _isSaving = false;

  late final _line1Ctrl = TextEditingController(text: widget.draft.line1);
  late final _line2Ctrl = TextEditingController(text: widget.draft.line2);
  late final _cityCtrl = TextEditingController(text: widget.draft.city);
  late final _villageCtrl = TextEditingController(text: widget.draft.village);
  late final _districtCtrl = TextEditingController(text: widget.draft.district);
  late final _stateCtrl = TextEditingController(text: widget.draft.state);
  late final _countryCtrl = TextEditingController(text: widget.draft.country);
  late final _postalCodeCtrl =
      TextEditingController(text: widget.draft.postalCode);

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  // Same location picker used by add_salon_screen.dart / add_branch_screen
  // .dart, for a consistent address-entry experience across the app. It
  // only returns a composed free-text address + coordinates, not
  // structured city/state/postalCode — updated_3 §5.2 requires those as
  // distinct fields, so they're reverse-geocoded from the coordinates
  // right after, then still editable manually below.
  Future<void> _chooseAddressLocation() async {
    if (widget.draft.hasAddress) return;
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
      _line2Ctrl.clear();
      _cityCtrl.text = resultText('city');
      _villageCtrl.clear();
      _districtCtrl.text = resultText('district');
      _stateCtrl.text = resultText('state');
      _countryCtrl.text = resultText('country');
      _postalCodeCtrl.text = resultText('postalCode');
      widget.draft.latitude = latitude;
      widget.draft.longitude = longitude;
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

  void _syncDraftFromControllers() {
    final draft = widget.draft;
    draft.line1 = _line1Ctrl.text.trim();
    draft.line2 = _line2Ctrl.text.trim();
    draft.city = _cityCtrl.text.trim();
    draft.village = _villageCtrl.text.trim();
    draft.district = _districtCtrl.text.trim();
    draft.state = _stateCtrl.text.trim();
    draft.country = _countryCtrl.text.trim();
    draft.postalCode = _postalCodeCtrl.text.trim();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncDraftFromControllers();
    final draft = widget.draft;

    final addressError = draft.addressCompletionError();
    if (addressError != null) {
      Fluttertoast.showToast(msg: addressError);
      return;
    }

    final fields = draft.buildPatchFields();
    if (fields.isEmpty) {
      Fluttertoast.showToast(msg: translateText('Nothing new to save'));
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
        Fluttertoast.showToast(msg: translateText('Profile updated'));
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

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Scaffold(
      backgroundColor: cpSurface,
      appBar: buildProfileSubpageAppBar(title: 'Complete Profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          MultiStepFlowHeader(currentStep: 4, useIcons: true, steps: _steps),
          const SizedBox(height: 20),
          const CpStepHeading(
            title: 'Address',
            subtitle: 'Last step — where is this team member based?',
          ),
          const SizedBox(height: 20),
          CpSectionCard(
            title: translateText('Address'),
            icon: Icons.place_outlined,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
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
                const SizedBox(height: 10),
                TextFormField(
                  controller: _line2Ctrl,
                  decoration:
                      cpInputDecoration(translateText('Address line 2')),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        decoration: cpInputDecoration(translateText('City')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _villageCtrl,
                        decoration: cpInputDecoration(translateText('Village')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _districtCtrl,
                        decoration:
                            cpInputDecoration(translateText('District')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stateCtrl,
                        decoration: cpInputDecoration(translateText('State')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _countryCtrl,
                        decoration: cpInputDecoration(translateText('Country')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeCtrl,
                        decoration:
                            cpInputDecoration(translateText('Postal code')),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: CpBottomButton(
        label: translateText('Save'),
        isBusy: _isSaving,
        onBack: _isSaving ? null : () => Navigator.pop(context),
        onPressed: _submit,
      ),
    );
  }
}
