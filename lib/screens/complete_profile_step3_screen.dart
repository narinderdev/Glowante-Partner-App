import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import 'complete_profile_shared.dart';
import 'complete_profile_step4_screen.dart';
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

class CompleteProfileStep3Screen extends StatefulWidget {
  const CompleteProfileStep3Screen({super.key, required this.draft});

  final CompleteProfileDraft draft;

  @override
  State<CompleteProfileStep3Screen> createState() =>
      _CompleteProfileStep3ScreenState();
}

class _CompleteProfileStep3ScreenState
    extends State<CompleteProfileStep3Screen> {
  void _onContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfileStep4Screen(draft: widget.draft),
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
          MultiStepFlowHeader(currentStep: 3, useIcons: true, steps: _steps),
          const SizedBox(height: 20),
          CpStepHeading(
            title: translateText('Specialities'),
            subtitle: translateText(
              'What can this member offer? This helps clients find the right stylist.',
            ),
          ),
          const SizedBox(height: 20),
          if (draft.hasSpecialities)
            CpSectionCard(
              title: translateText('Specialities'),
              icon: Icons.star_border_rounded,
              children: [
                CpLockedValueChip(
                  value: (draft.profile['specialities'] as List)
                      .whereType<Map>()
                      .map((s) => (s['name'] ?? s['code'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                ),
              ],
            )
          else if (draft.specialityOptions.isEmpty)
            CpSectionCard(
              title: translateText('Specialities'),
              icon: Icons.star_border_rounded,
              children: [
                Text(
                  translateText('No specialities available'),
                  style: const TextStyle(color: cpMuted, fontSize: 12.5),
                ),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  translateText('Choose what applies'),
                  style: const TextStyle(
                    color: cpInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                CpCountPill(
                  selected: draft.specialityCodes.length,
                  total: draft.specialityOptions.length,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...draft.specialityOptions.map((option) {
              final code = (option['code'] ?? option['name'] ?? '').toString();
              final label = (option['name'] ?? option['code'] ?? '').toString();
              final selected = draft.specialityCodes.contains(code);
              return CpSelectableRow(
                label: label,
                selected: selected,
                onTap: () {
                  if (!selected && draft.specialityCodes.length >= 10) {
                    Fluttertoast.showToast(
                      msg: translateText(
                        'You can select up to 10 specialities',
                      ),
                    );
                    return;
                  }
                  setState(() {
                    if (selected) {
                      draft.specialityCodes.remove(code);
                    } else {
                      draft.specialityCodes.add(code);
                    }
                  });
                },
              );
            }),
          ],
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
