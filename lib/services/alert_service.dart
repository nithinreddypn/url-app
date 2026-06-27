import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'exception_mapper.dart';

enum AlertType { success, error, warning, info }

class AlertService {
  /// Displays a premium Material 3 floating notification with smooth animations,
  /// rounded corners, soft shadows, and clean glassmorphism styling.
  static void showAlert(
    BuildContext context, {
    required AlertType type,
    required String title,
    required String description,
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium accessible styling parameters based on AlertType
    Color bgColor;
    Color iconColor;
    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    Color descColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
    IconData iconData;

    switch (type) {
      case AlertType.success:
        bgColor = isDark 
            ? const Color(0xFF064E3B).withValues(alpha: 0.9) 
            : const Color(0xFFECFDF5).withValues(alpha: 0.95);
        iconColor = const Color(0xFF10B981); // Emerald Green
        iconData = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        bgColor = isDark 
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.9) 
            : const Color(0xFFFEF2F2).withValues(alpha: 0.95);
        iconColor = const Color(0xFFEF4444); // Red
        iconData = Icons.error_rounded;
        break;
      case AlertType.warning:
        bgColor = isDark 
            ? const Color(0xFF78350F).withValues(alpha: 0.9) 
            : const Color(0xFFFFFBEB).withValues(alpha: 0.95);
        iconColor = const Color(0xFFF59E0B); // Orange
        iconData = Icons.warning_rounded;
        break;
      case AlertType.info:
        bgColor = isDark 
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.9) 
            : const Color(0xFFEFF6FF).withValues(alpha: 0.95);
        iconColor = const Color(0xFF3B82F6); // Blue
        iconData = Icons.info_rounded;
        break;
    }

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      duration: const Duration(seconds: 4),
      dismissDirection: DismissDirection.horizontal,
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }

  /// Displays a friendly Success Alert.
  static void showSuccess(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.success, title: title, description: description);
  }

  /// Centralized mapping of any caught exception to show a friendly Error Alert.
  static void showError(BuildContext context, dynamic error, {String? customTitle}) {
    final mapped = ExceptionMapper.map(error);
    showAlert(
      context,
      type: AlertType.error,
      title: customTitle ?? mapped.title,
      description: mapped.description,
    );
  }

  /// Displays a Warning Alert.
  static void showWarning(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.warning, title: title, description: description);
  }

  /// Displays an Informational Alert.
  static void showInfo(BuildContext context, String title, String description) {
    showAlert(context, type: AlertType.info, title: title, description: description);
  }
}
