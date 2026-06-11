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
    required this.activeColor,
    required this.inactiveFillColor,
    required this.inactiveBorderColor,
  });

  final int stepNumber;
  final String label;
  final IconData? icon;
  final bool active;
  final bool completed;
  final Color activeColor;
  final Color inactiveFillColor;
  final Color inactiveBorderColor;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || completed;
    final resolvedIcon = icon ?? _defaultIconForStep(stepNumber, label);
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
          child: active && resolvedIcon != null
              ? Icon(
                  resolvedIcon,
                  size: 18,
                  color: Colors.white,
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
          height: 20,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1.1,
              color: active ? activeColor : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  IconData? _defaultIconForStep(int stepNumber, String label) {
    final normalizedLabel = label.toLowerCase();
    if (normalizedLabel.contains('branch') ||
        normalizedLabel.contains('location')) {
      return Icons.place_outlined;
    }
    if (normalizedLabel.contains('service')) {
      return Icons.content_cut_rounded;
    }
    if (normalizedLabel.contains('schedule') ||
        normalizedLabel.contains('time')) {
      return Icons.calendar_today_outlined;
    }
    if (normalizedLabel.contains('availability')) {
      return Icons.event_available_outlined;
    }
    if (normalizedLabel.contains('complete')) {
      return Icons.check_circle_outline;
    }
    if (normalizedLabel.contains('personal') || stepNumber == 1) {
      return Icons.person_outline_rounded;
    }
    return null;
  }
}
