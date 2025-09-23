import 'package:flutter/material.dart';

class StepHeader extends StatelessWidget {
  final int currentStep; // 1..4
  const StepHeader({Key? key, required this.currentStep}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget circle(int n, String label) {
      final bool completed = n < currentStep;
      final bool active = n == currentStep;

      return _StepCircle(
        number: n,
        label: label,
        completed: completed,
        active: active,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        circle(1, "Select Branches"),
        circle(2, "Services"),
        circle(3, "Schedule"),
        circle(4, "Complete"),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final String label;
  final bool completed;
  final bool active;

  const _StepCircle({
    Key? key,
    required this.number,
    required this.label,
    required this.completed,
    required this.active,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.orange;
    final Color idleColor = Colors.grey.shade300;

    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: completed || active ? activeColor : idleColor,
          child: completed
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Text(
                  number.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: completed || active ? activeColor : Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
