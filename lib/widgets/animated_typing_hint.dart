import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedTypingHint extends StatefulWidget {
  const AnimatedTypingHint({
    super.key,
    required this.hints,
    required this.style,
    this.prefix = '',
    this.typingDelay = const Duration(milliseconds: 75),
    this.deletingDelay = const Duration(milliseconds: 35),
    this.pauseDelay = const Duration(milliseconds: 1100),
    this.maxLines = 1,
  });

  final List<String> hints;
  final TextStyle style;
  final String prefix;
  final Duration typingDelay;
  final Duration deletingDelay;
  final Duration pauseDelay;
  final int maxLines;

  @override
  State<AnimatedTypingHint> createState() => _AnimatedTypingHintState();
}

class _AnimatedTypingHintState extends State<AnimatedTypingHint> {
  Timer? _timer;
  int _hintIndex = 0;
  int _visibleCharacters = 0;
  bool _isDeleting = false;
  bool _isPaused = false;

  List<String> get _hints =>
      widget.hints.where((hint) => hint.trim().isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _scheduleNextTick(widget.typingDelay);
  }

  @override
  void didUpdateWidget(covariant AnimatedTypingHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hints.join('|') != widget.hints.join('|')) {
      _timer?.cancel();
      _hintIndex = 0;
      _visibleCharacters = 0;
      _isDeleting = false;
      _isPaused = false;
      _scheduleNextTick(widget.typingDelay);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextTick(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    final hints = _hints;
    if (!mounted || hints.isEmpty) return;
    final currentHint = hints[_hintIndex % hints.length];

    setState(() {
      if (_isPaused) {
        _isPaused = false;
        _isDeleting = true;
      } else if (_isDeleting) {
        _visibleCharacters =
            (_visibleCharacters - 1).clamp(0, currentHint.length);
        if (_visibleCharacters == 0) {
          _isDeleting = false;
          _hintIndex = (_hintIndex + 1) % hints.length;
        }
      } else {
        _visibleCharacters =
            (_visibleCharacters + 1).clamp(0, currentHint.length);
        if (_visibleCharacters == currentHint.length) {
          _isPaused = true;
        }
      }
    });

    _scheduleNextTick(
      _isPaused
          ? widget.pauseDelay
          : _isDeleting
              ? widget.deletingDelay
              : widget.typingDelay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hints = _hints;
    if (hints.isEmpty) return const SizedBox.shrink();

    final currentHint = hints[_hintIndex % hints.length];
    final safeCharacters = _visibleCharacters.clamp(0, currentHint.length);
    final text = currentHint.substring(0, safeCharacters);

    return Text(
      '${widget.prefix}$text',
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
