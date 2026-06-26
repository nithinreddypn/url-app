import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class ScanLimitDialog extends StatelessWidget {
  const ScanLimitDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final surfaceColor = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final primaryGreen = context.activeAccent;
    final errorRed = context.isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: surfaceColor, width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: errorRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: errorRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Free Scan Limit Reached',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You've used your 1 free scan for this week. Upgrade to URL Defender Plus to unlock:",
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureRow(Icons.check_circle_outline_rounded, 'Unlimited URL Scans', primaryGreen, textPrimary),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.psychology_outlined, 'AI Threat Analysis', primaryGreen, textPrimary),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.share_outlined, 'Community Threat Intelligence', primaryGreen, textPrimary),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.speed_rounded, 'Priority Processing', primaryGreen, textPrimary),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: textSecondary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: context.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.activeAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/premium');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Upgrade to Plus',
                    style: TextStyle(
                      color: Color(0xFF121212),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color primaryGreen, Color textPrimary) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
