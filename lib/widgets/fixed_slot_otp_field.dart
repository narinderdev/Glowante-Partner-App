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

// A single real, invisible TextField drives every visual box — there is
// only ever one native keyboard/text-input connection for the whole
// field, so focus never has to hop between separate per-digit TextFields
// as the user types. That per-box hopping (each box its own TextField +
// FocusNode) was what caused the keyboard to visibly flicker on iOS with
// every keystroke, even after deferring the focus-change calls by a
// frame — the only full fix is to not have multiple text inputs at all.
class _FixedSlotOtpFieldState extends State<FixedSlotOtpField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;

    if (limited != _controller.text) {
      _controller.value = TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }

    setState(() {});
    widget.onChanged(limited, limited.length == widget.length);

    if (limited.length == widget.length) {
      widget.onSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final activeIndex = text.length.clamp(0, widget.length - 1);

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            final digit = index < text.length ? text[index] : '';
            final filled = digit.isNotEmpty;
            final isActive =
                widget.enabled && _focusNode.hasFocus && index == activeIndex;

            final borderColor = widget.hasError
                ? widget.errorColor
                : isActive || filled
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
                  width: isActive || filled ? 1.7 : 1.3,
                ),
              ),
              child: Text(
                digit,
                style: TextStyle(
                  color: filled && widget.filledColor != null
                      ? widget.filledTextColor
                      : widget.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              // Explicitly empty (not null) opts out of the platform's
              // autofill framework here — autofill is handled by the
              // screen embedding this field (e.g. SMS retriever), not by
              // this hidden field itself.
              autofillHints: const <String>[],
              enableSuggestions: false,
              autocorrect: false,
              showCursor: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _handleChanged,
            ),
          ),
        ),
      ],
    );
  }
}
