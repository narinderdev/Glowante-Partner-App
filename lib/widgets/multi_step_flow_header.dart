import 'package:flutter/material.dart';

class MultiStepFlowHeader extends StatelessWidget {
  const MultiStepFlowHeader({
    super.key,
    required this.currentStep,
    required this.steps,
    this.useIcons = false,
    this.activeColor = const Color(0xFF8B6500),
    this.inactiveFillColor = const Color(0xFFECE7E1),
    this.inactiveBorderColor = const Color(0xFFD8C7B3),
  });

  final int currentStep;
  final List<FlowStepItem> steps;
  final bool useIcons;
  final Color activeColor;
  final Color inactiveFillColor;
  final Color inactiveBorderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int index = 0; index < steps.length; index++) ...[
          Expanded(
            child: _FlowNode(
              stepNumber: steps[index].stepNumber,
              label: steps[index].label,
              icon: steps[index].icon,
              active: currentStep == steps[index].stepNumber,
              completed: currentStep > steps[index].stepNumber,
              useIcons: useIcons,
              activeColor: activeColor,
              inactiveFillColor: inactiveFillColor,
              inactiveBorderColor: inactiveBorderColor,
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 26),
                color: currentStep > steps[index].stepNumber
                    ? activeColor
                    : inactiveBorderColor,
              ),
            ),
        ],
      ],
    );
  }
}

class FlowStepItem {
  const FlowStepItem({
    required this.stepNumber,
    required this.label,
    this.icon,
  });

  final int stepNumber;
  final String label;
  final IconData? icon;
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.stepNumber,
    required this.label,
    required this.icon,
    required this.active,
    required this.completed,
    required this.useIcons,
    required this.activeColor,
    required this.inactiveFillColor,
    required this.inactiveBorderColor,
  });

  final int stepNumber;
  final String label;
  final IconData? icon;
  final bool active;
  final bool completed;
  final bool useIcons;
  final Color activeColor;
  final Color inactiveFillColor;
  final Color inactiveBorderColor;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted ? activeColor : inactiveFillColor,
            border: Border.all(
              color: highlighted ? activeColor : inactiveBorderColor,
            ),
          ),
          alignment: Alignment.center,
          child: useIcons && icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: highlighted ? Colors.white : const Color(0xFF8D867F),
                )
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    color: highlighted ? Colors.white : const Color(0xFF8D867F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
