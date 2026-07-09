import 'dart:ui';
import 'package:flutter/material.dart';
import 'exception_mapper.dart';

enum AlertType { success, error, warning, info }

class AlertService {
  /// Displays a premium SaaS-style glassmorphism floating notification with
  /// rounded corners, soft shadows, and an animated progress indicator.
  static void showAlert(
    BuildContext context, {
    required AlertType type,
    required String title,
    required String description,
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium accessible styling parameters based on AlertType
    Color baseColor;
    String prefixSymbol;
    IconData iconData;

    switch (type) {
      case AlertType.success:
        baseColor = const Color(0xFF10B981); // Emerald Green
        prefixSymbol = '✓';
        iconData = Icons.check_circle_outline_rounded;
        break;
      case AlertType.error:
        baseColor = const Color(0xFFEF4444); // Red
        prefixSymbol = '⚠️';
        iconData = Icons.error_outline_rounded;
        break;
      case AlertType.warning:
        baseColor = const Color(0xFFF59E0B); // Orange
        prefixSymbol = '⚠️';
        iconData = Icons.warning_amber_rounded;
        break;
      case AlertType.info:
        baseColor = const Color(0xFF3B82F6); // Blue
        prefixSymbol = 'ℹ️';
        iconData = Icons.info_outline_rounded;
        break;
    }

    // Modern glassmorphism translucent background colors
    final Color bgColor = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.75) // Slate 900
        : const Color(0xFFFFFFFF).withValues(alpha: 0.75);

    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color descColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      duration: const Duration(milliseconds: 5000), // 5 seconds auto-close
      dismissDirection: DismissDirection.horizontal,
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: baseColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        iconData,
                        color: baseColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$prefixSymbol $title',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: descColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Animated Progress Timer bar at the bottom
                _ToastTimerBar(
                  color: baseColor,
                  duration: const Duration(milliseconds: 5000),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.success, title: title, description: description);
  }

  static void showError(BuildContext context, dynamic error, {String? customTitle}) {
    final mapped = ExceptionMapper.map(error);
    showAlert(
      context,
      type: AlertType.error,
      title: customTitle ?? mapped.title,
      description: mapped.description,
    );
  }

  static void showWarning(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.warning, title: title, description: description);
  }

  static void showInfo(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.info, title: title, description: description);
  }
}

/// A stateful timer bar that drains from right to left (value: 1.0 to 0.0)
/// over the duration of the notification.
class _ToastTimerBar extends StatefulWidget {
  final Color color;
  final Duration duration;

  const _ToastTimerBar({
    required this.color,
    required this.duration,
  });

  @override
  State<_ToastTimerBar> createState() => _ToastTimerBarState();
}

class _ToastTimerBarState extends State<_ToastTimerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.reverse(from: 1.0); // Drain progress bar from 100% to 0%
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _controller.value,
            child: Container(
              height: 3,
              color: widget.color.withValues(alpha: 0.6),
            ),
          ),
        );
      },
    );
  }
}
