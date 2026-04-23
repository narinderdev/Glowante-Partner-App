import 'package:flutter/material.dart';

class SalonFlowStepHeader extends StatelessWidget {
  const SalonFlowStepHeader({
    super.key,
    required this.currentStep,
    required this.detailsLabel,
    this.totalSteps = 3,
  });

  final int currentStep;
  final String detailsLabel;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _FlowStepData(1, detailsLabel),
      const _FlowStepData(2, 'Set Schedule'),
      if (totalSteps >= 3) const _FlowStepData(3, 'Select Services'),
    ];

    return Row(
      children: [
        for (int index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _FlowStepIndicator(
              number: steps[index].number,
              label: steps[index].label,
              active: currentStep == steps[index].number,
              completed: currentStep > steps[index].number,
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 24),
                color: currentStep > steps[index].number
                    ? const Color(0xFFE4900F)
                    : const Color(0xFFD1D5DB),
              ),
            ),
        ],
      ],
    );
  }
}

class _FlowStepData {
  const _FlowStepData(this.number, this.label);

  final int number;
  final String label;
}

class _FlowStepIndicator extends StatelessWidget {
  const _FlowStepIndicator({
    required this.number,
    required this.label,
    required this.active,
    required this.completed,
  });

  final int number;
  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = active || completed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHighlighted ? const Color(0xFFE4900F) : Colors.white,
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFFE4900F)
                  : const Color(0xFFD1D5DB),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              color: isHighlighted ? Colors.white : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFFE4900F) : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
