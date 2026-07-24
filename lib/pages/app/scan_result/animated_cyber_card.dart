import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AnimatedCyberCard extends StatefulWidget {
  final Widget child;
  final Color accentColor;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const AnimatedCyberCard({
    super.key,
    required this.child,
    required this.accentColor,
    this.onTap,
    required this.semanticsLabel,
  });

  @override
  State<AnimatedCyberCard> createState() => _AnimatedCyberCardState();
}

class _AnimatedCyberCardState extends State<AnimatedCyberCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    if (_isPressed) {
      scale = 0.98;
    } else if (_isHovered) {
      scale = 1.02;
    }

    return Semantics(
      label: widget.semanticsLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: context.cardBg.withOpacity(context.isDark ? 0.45 : 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovered
                      ? widget.accentColor.withOpacity(0.35)
                      : widget.accentColor.withOpacity(0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? widget.accentColor.withOpacity(0.08)
                        : widget.accentColor.withOpacity(0.02),
                    blurRadius: _isHovered ? 24 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
