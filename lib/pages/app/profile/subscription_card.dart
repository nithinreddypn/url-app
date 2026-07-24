import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../../../services/alert_service.dart';
import '../../../views/premium_screen.dart';

class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final scansAsync = ref.watch(scanLimitProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final primaryBlue = const Color(0xFF3B82F6);
    final primaryGreen = const Color(0xFF10B981);

    if (user == null) return const SizedBox.shrink();

    final isPremium = user.isPremium;
    final planName = isPremium ? 'PREMIUM' : 'FREE';
    final planDesc = isPremium
        ? 'Unlimited scans, priority intelligence, multi-device sync.'
        : '50 scans per month, real-time detection, full history.';
    
    final limit = isPremium ? 1000 : 50;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Plan Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPremium
                      ? primaryGreen.withOpacity(0.12)
                      : primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPremium
                        ? primaryGreen.withOpacity(0.3)
                        : primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPremium ? Icons.auto_awesome_rounded : Icons.star_border_rounded,
                      color: isPremium ? primaryGreen : primaryBlue,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      planName,
                      style: TextStyle(
                        color: isPremium ? primaryGreen : primaryBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan Description
          Text(
            planDesc,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Usage & Progress Bar
          scansAsync.when(
            data: (remainingScans) {
              final used = (50 - remainingScans).clamp(0, 50);
              final pct = limit > 0 ? (used / limit) * 100 : 0.0;
              final clampedPct = pct.clamp(0.0, 100.0);

              // Progress bar fill color logic:
              // 0-69% = blue, 70-89% = amber, 90-100% = red/destructive
              Color progressColor;
              if (clampedPct < 70.0) {
                progressColor = primaryBlue;
              } else if (clampedPct < 90.0) {
                progressColor = Colors.amber;
              } else {
                progressColor = Colors.red;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Usage row text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lifetime scans',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$used of $limit',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar (~8px height, rounded)
                  Semantics(
                    value: '${clampedPct.round()}%',
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: clampedPct.round(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: (100 - clampedPct.round()).clamp(0, 100),
                            child: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: textSecondary))),
          ),
          const SizedBox(height: 24),

          // Upgrade plan button
          if (!isPremium)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
              label: const Text(
                'Upgrade plan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
