import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FixedSlotOtpField extends StatefulWidget {
  const FixedSlotOtpField({
    super.key,
    required this.onChanged,
    this.length = 6,
    this.enabled = true,
    this.hasError = false,
    this.onSubmitted,
    this.fieldWidth = 44,
    this.fieldHeight = 54,
    this.activeColor = const Color(0xFF8B6500),
    this.inactiveColor = const Color(0xFFE8DED6),
    this.errorColor = Colors.red,
    this.fillColor = Colors.white,
    this.filledColor,
    this.textColor = const Color(0xFF1F1B18),
    this.filledTextColor = Colors.white,
    this.borderRadius = 10,
  });

  final int length;
  final bool enabled;
  final bool hasError;
  final double fieldWidth;
  final double fieldHeight;
  final Color activeColor;
  final Color inactiveColor;
  final Color errorColor;
  final Color fillColor;
  final Color? filledColor;
  final Color textColor;
  final Color filledTextColor;
  final double borderRadius;
  final void Function(String otp, bool complete) onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<FixedSlotOtpField> createState() => _FixedSlotOtpFieldState();
}

class _FixedSlotOtpFieldState extends State<FixedSlotOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updating = false;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );

    _focusNodes = List.generate(
      widget.length,
      (_) => FocusNode(),
    );

    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _otpValue() {
    return _controllers.map((c) => c.text).join();
  }

  bool _isComplete() {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  void _notify() {
    widget.onChanged(_otpValue(), _isComplete());
  }

  void _focusSlot(int index) {
    if (!widget.enabled) return;

    final safeIndex = index.clamp(0, widget.length - 1).toInt();

    FocusScope.of(context).requestFocus(_focusNodes[safeIndex]);

    _controllers[safeIndex].selection = TextSelection.collapsed(
      offset: _controllers[safeIndex].text.length,
    );
  }

  void _setSlot(int index, String digit) {
    _controllers[index].text = digit;
    _controllers[index].selection = TextSelection.collapsed(
      offset: digit.length,
    );
  }

  void _handleChanged(int index, String value) {
    if (_updating) return;

    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Paste/autofill case: fill from current index forward.
    if (digits.length > 1) {
      _updating = true;

      for (int i = 0; i < digits.length; i++) {
        final slotIndex = index + i;
        if (slotIndex >= widget.length) break;
        _setSlot(slotIndex, digits[i]);
      }

      _updating = false;

      setState(() {});
      _notify();

      final nextIndex = (index + digits.length).clamp(
        0,
        widget.length - 1,
      );

      _focusSlot(nextIndex);

      if (_isComplete()) {
        widget.onSubmitted?.call();
      }

      return;
    }

    _updating = true;

    if (digits.isEmpty) {
      // Do not shift other OTP digits.
      // Just clear this selected box.
      _controllers[index].clear();
    } else {
      _setSlot(index, digits);
    }

    _updating = false;

    setState(() {});
    _notify();

    if (digits.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusSlot(index + 1);
      } else if (_isComplete()) {
        widget.onSubmitted?.call();
      }
    }
  }

  void _handleBackspace(int index) {
    if (!widget.enabled) return;

    // If current box has value, clear only current box.
    // Example: 1 2 3 4 5 6, focus on 2 => 1 _ 3 4 5 6
    if (_controllers[index].text.isNotEmpty) {
      _controllers[index].clear();

      setState(() {});
      _notify();
      _focusSlot(index);
      return;
    }

    // If current box is already empty, go previous and clear previous.
    if (index > 0) {
      _controllers[index - 1].clear();

      setState(() {});
      _notify();
      _focusSlot(index - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        final filled = _controllers[index].text.isNotEmpty;
        final focused = _focusNodes[index].hasFocus && widget.enabled;

        final borderColor = widget.hasError
            ? widget.errorColor
            : focused || filled
                ? widget.activeColor
                : widget.inactiveColor;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.fieldWidth,
          height: widget.fieldHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled && widget.filledColor != null
                ? widget.filledColor
                : widget.fillColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: borderColor,
              width: focused || filled ? 1.7 : 1.3,
            ),
          ),
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                _handleBackspace(index);
              }
            },
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: index == widget.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              maxLength: 1,
              autofillHints:
                  index == 0 ? const [AutofillHints.oneTimeCode] : null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: filled && widget.filledColor != null
                    ? widget.filledTextColor
                    : widget.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              cursorColor: filled && widget.filledColor != null
                  ? widget.filledTextColor
                  : widget.activeColor,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                isDense: true,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () => _focusSlot(index),
              onChanged: (value) => _handleChanged(index, value),
              onSubmitted: (_) {
                if (index < widget.length - 1) {
                  _focusSlot(index + 1);
                } else if (_isComplete()) {
                  widget.onSubmitted?.call();
                }
              },
            ),
          ),
        );
      }),
    );
  }
}