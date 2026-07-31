import 'dart:async';
import 'package:flutter/material.dart';

/// Purely presentational typewriter animation that cycles through sample URLs.
/// Controlled via [paused] — stops when the field has focus/text, a scan is
/// running, or reduced-motion is enabled.
class TypewriterHint extends StatefulWidget {
  final bool paused;
  final ValueChanged<String> onHintChanged;

  const TypewriterHint({
    super.key,
    required this.paused,
    required this.onHintChanged,
  });

  @override
  State<TypewriterHint> createState() => _TypewriterHintState();
}

class _TypewriterHintState extends State<TypewriterHint> {
  static const _urls = [
    'https://example.com/login',
    'https://paypa1-secure.co/verify',
    'https://drive.google.com/file/xyz',
    'https://bit.ly/free-gift-card',
    'https://github.com/tanstack/router',
  ];

  Timer? _timer;
  int _urlIndex = 0;
  int _charIndex = 0;
  bool _isErasing = false;
  String _currentHint = '';

  @override
  void initState() {
    super.initState();
    if (!widget.paused) _startAnimation();
  }

  @override
  void didUpdateWidget(covariant TypewriterHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && !oldWidget.paused) {
      _stopAnimation();
    } else if (!widget.paused && oldWidget.paused) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    final ms = _isErasing ? 25 : 70;
    _timer = Timer.periodic(Duration(milliseconds: ms), _tick);
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(Timer timer) {
    if (!mounted || widget.paused) {
      timer.cancel();
      return;
    }
    final currentWord = _urls[_urlIndex];

    if (!_isErasing) {
      // Typing forward
      _charIndex++;
      _currentHint = currentWord.substring(0, _charIndex);
      widget.onHintChanged(_currentHint);

      if (_charIndex >= currentWord.length) {
        // Pause at full text, then start erasing
        timer.cancel();
        _timer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted && !widget.paused) {
            _isErasing = true;
            _startAnimation();
          }
        });
      }
    } else {
      // Erasing backward
      _charIndex--;
      _currentHint = _charIndex > 0 ? currentWord.substring(0, _charIndex) : '';
      widget.onHintChanged(_currentHint);

      if (_charIndex <= 0) {
        // Move to next URL
        timer.cancel();
        _isErasing = false;
        _urlIndex = (_urlIndex + 1) % _urls.length;
        _timer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && !widget.paused) {
            _startAnimation();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible — it only drives the hint text
    // via the onHintChanged callback
    return const SizedBox.shrink();
  }
}
