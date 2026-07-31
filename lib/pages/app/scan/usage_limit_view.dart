import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'scan_theme.dart';

/// Replaces the scan form when the user has reached their usage limit.
class UsageLimitView extends StatelessWidget {
  final int used;
  final int limit;
  final VoidCallback onUpgrade;
  final VoidCallback onBackToDashboard;

  const UsageLimitView({
    super.key,
    required this.used,
    required this.limit,
    required this.onUpgrade,
    required this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final isDark = context.isDark;
    final progress = (used / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(ScanTokens.cardRadius),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amber icon badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ScanTokens.amberBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: ScanTokens.amber.withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: ScanTokens.amber,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          Text(
            'Monthly limit reached',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Body text
          Text(
            'You\'ve used all $used of your $limit free scans this month. Upgrade for unlimited access or wait for your quota to reset.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Progress bar + counter
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.06),
                      color: ScanTokens.amber,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$used/$limit',
                style: ScanTokens.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upgrade CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: ScanTokens.amber,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(ScanTokens.innerRadius),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Upgrade for unlimited scans',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Back to dashboard
          TextButton(
            onPressed: onBackToDashboard,
            style: TextButton.styleFrom(
              foregroundColor: textMuted,
              minimumSize: const Size(48, 40),
            ),
            child: const Text(
              'Back to dashboard',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),

          // Footer note
          Text(
            'Your quota resets on the 1st of next month.',
            style: TextStyle(
              fontSize: 11,
              color: textMuted.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
