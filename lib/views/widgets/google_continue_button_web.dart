import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../services/google_sign_in_service.dart';

/// Full Google Sign-In button for web.
/// Renders the custom "Continue with Google" UI and calls
/// google.accounts.id.prompt() via JS interop on tap.
/// Tokens come via [GoogleSignInService.webIdTokens] stream.
class GoogleContinueButton extends StatefulWidget {
  const GoogleContinueButton({
    required this.isLoading,
    required this.onIdToken,
    required this.onError,
    super.key,
  });

  final bool isLoading;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error, StackTrace stackTrace) onError;

  @override
  State<GoogleContinueButton> createState() => _GoogleContinueButtonState();
}

class _GoogleContinueButtonState extends State<GoogleContinueButton> {
  StreamSubscription<String>? _tokenSubscription;
  bool _isHovered = false;
  bool _isPressed = false;

  static bool _isDismissalError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('dismissed') ||
        msg.contains('suppressed') ||
        msg.contains('opt_out') ||
        msg.contains('fedcm') ||
        msg.contains('networkerror') ||
        msg.contains('cool') ||
        msg.contains('cancelled') ||
        msg.contains('canceled');
  }

  @override
  void initState() {
    super.initState();
    _tokenSubscription = GoogleSignInService.instance.webIdTokens.listen(
      (idToken) async {
        if (!mounted || widget.isLoading) return;
        try {
          await widget.onIdToken(idToken);
        } catch (error, stackTrace) {
          if (mounted) widget.onError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted && !_isDismissalError(error)) {
          widget.onError(error, stackTrace);
        }
      },
    );
    GoogleSignInService.instance.initialize().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('[GoogleContinueButton] GSI init: $error');
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  void _triggerGoogleSignIn() {
    try {
      final winObj = web.window as JSObject;
      final google = winObj.getProperty<JSAny?>('google'.toJS);
      if (google == null) return;
      final accounts =
          (google as JSObject).getProperty<JSAny?>('accounts'.toJS);
      if (accounts == null) return;
      final id = (accounts as JSObject).getProperty<JSAny?>('id'.toJS);
      if (id == null) return;
      (id as JSObject).callMethod<JSAny?>('prompt'.toJS);
    } catch (e) {
      debugPrint('[GoogleContinueButton] prompt() error: $e');
      if (!_isDismissalError(e)) {
        widget.onError(
          Exception('Google Sign-In could not be started. Please try again.'),
          StackTrace.current,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final hoverColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final pressColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    Color currentBg = bgColor;
    if (_isPressed) currentBg = pressColor;
    else if (_isHovered) currentBg = hoverColor;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: MouseRegion(
        cursor: widget.isLoading
            ? SystemMouseCursors.wait
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.isLoading ? null : _triggerGoogleSignIn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: currentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomPaint(painter: const GoogleLogoPainter()),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A pixel-perfect, clean, solid-fill vector implementation of the
/// official Google "G" logo.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    
    // Thickness of the "G" ring (approx 28% of diameter)
    final double strokeWidth = size.width * 0.28;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeWidth / 2);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const double d = math.pi / 180;

    // 1. Red (Top Segment)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -145 * d, 103 * d, false, paint);

    // 2. Yellow (Left Segment)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -250 * d, 107 * d, false, paint);

    // 3. Green (Bottom Segment)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 35 * d, 110 * d, false, paint);

    // 4. Blue (Right Segment & Horizontal Bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -42 * d, 78 * d, false, paint);

    // Draw the horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    final double barHeight = strokeWidth * 0.95;
    final double barLeft = cx - r * 0.05;
    final double barWidth = r + strokeWidth / 2 - (barLeft - cx);
    
    canvas.drawRect(
      Rect.fromLTWH(barLeft, cy - barHeight / 2, barWidth, barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
