import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'complete_profile_shared.dart';
import 'complete_profile_step3_screen.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';
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

class CompleteProfileStep2Screen extends StatefulWidget {
  const CompleteProfileStep2Screen({super.key, required this.draft});

  final CompleteProfileDraft draft;

  @override
  State<CompleteProfileStep2Screen> createState() =>
      _CompleteProfileStep2ScreenState();
}

class _CompleteProfileStep2ScreenState
    extends State<CompleteProfileStep2Screen> {
  late final _bioCtrl = TextEditingController(text: widget.draft.bio);

  // Only shows after a Continue attempt, and only for a bio the user is
  // actually meant to type here — an already-locked bio (draft.hasBio)
  // is shown read-only, so it can never be "empty" from this field's
  // point of view.
  bool _showValidationErrors = false;

  bool get _bioHasError =>
      _showValidationErrors &&
      !widget.draft.hasBio &&
      _bioCtrl.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    // Re-render on every keystroke so _bioHasError clears the moment the
    // field stops being empty, instead of only after the next Continue tap.
    _bioCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCareerStartDate() async {
    final draft = widget.draft;
    if (draft.hasCareerStartDate) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Career start date must be strictly in the past — today itself isn't
    // a valid "start date" for career length purposes, so the latest
    // selectable day is yesterday.
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

  void _onContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _showValidationErrors = true);
    if (_bioHasError) return;

    widget.draft.bio = _bioCtrl.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfileStep3Screen(draft: widget.draft),
      ),
    );
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
          MultiStepFlowHeader(currentStep: 2, useIcons: true, steps: _steps),
          const SizedBox(height: 20),
          const CpStepHeading(
            title: 'Career Details',
            subtitle:
                'When did they start their career, and how would you describe them?',
          ),
          const SizedBox(height: 20),
          CpSectionCard(
            title: translateText('Career start date'),
            icon: Icons.work_outline_rounded,
            children: [
              CpLockableField(
                label: translateText('Career start date'),
                isLocked: draft.hasCareerStartDate,
                lockedValue: draft.profile['careerStartDate']?.toString(),
                child: InkWell(
                  onTap: _pickCareerStartDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: cpInputDecoration(translateText('Select date'))
                        .copyWith(
                      prefixIcon: const Icon(Icons.calendar_today_outlined,
                          size: 16, color: cpMuted),
                      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: cpMuted),
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
                          'n': '${draft.profile['careerExperienceYears']}',
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
          CpSectionCard(
            title: '${translateText('Bio')} *',
            icon: Icons.description_outlined,
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
                    errorText: _bioHasError
                        ? translateText('Bio is required')
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: CpBottomButton(
        label: translateText('Continue'),
        isBusy: false,
        onBack: () => Navigator.pop(context),
        onPressed: _onContinue,
      ),
    );
  }
}
