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
      _FlowStepData(1, _shortDetailsLabel(detailsLabel)),
      const _FlowStepData(2, 'Schedule'),
      if (totalSteps >= 3) const _FlowStepData(3, 'Services'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < steps.length; index++) ...[
          SizedBox(
            width: 54,
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
                height: 1.5,
                margin: const EdgeInsets.only(top: 17),
                color: currentStep > steps[index].number
                    ? const Color(0xFFD0A244)
                    : const Color(0xFFE8E2DC),
              ),
            ),
        ],
      ],
    );
  }

  String _shortDetailsLabel(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('branch')) return 'Details';
    if (normalized.contains('salon')) return 'Details';
    return value;
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
    const accent = Color(0xFF936D00);
    const completedColor = Color(0xFFD8CDBD);
    const inactiveBorder = Color(0xFFD8CDBD);
    const inactiveFill = Color(0xFFFBFAF9);
    final fill = active ? accent : (completed ? completedColor : inactiveFill);
    final border = active || completed ? fill : inactiveBorder;
    final textColor =
        active || completed ? Colors.white : const Color(0xFF6F6257);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: 1.5),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x1F936D00),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: completed
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            height: 1.1,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? accent : const Color(0xFF3B332B),
          ),
        ),
      ],
    );
  }
}
