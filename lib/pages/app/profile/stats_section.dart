import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';

class StatsSection extends ConsumerWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(scanHistoryProvider);
    final remainingScansAsync = ref.watch(scanLimitProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 640 && screenWidth < 1024;

    return scansAsync.when(
      data: (scans) {
        final user = ref.read(userProvider);
        final isPremium = user?.isPremium ?? false;
        final totalLimit = isPremium ? 1000 : 50;
        final remainingScans = remainingScansAsync.valueOrNull ?? totalLimit;
        final totalScans = (totalLimit - remainingScans).clamp(0, totalLimit);
        
        final threatsFound = scans.where((s) {
          final res = s.scanResult?.toLowerCase() ?? '';
          return res == 'dangerous' || res == 'suspicious';
        }).length;
        final safeScans = scans.where((s) => s.scanResult?.toLowerCase() == 'safe').length;

        final cards = [
          StatCard(
            label: 'TOTAL SCANS',
            value: totalScans,
            icon: Icons.qr_code_scanner_rounded,
            color: Colors.blue,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            textPrimary: textPrimary,
          ),
          StatCard(
            label: 'THREATS FOUND',
            value: threatsFound,
            icon: Icons.shield_outlined,
            color: Colors.red,
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            textPrimary: textPrimary,
          ),
          StatCard(
            label: 'SAFE URLS',
            value: safeScans,
            icon: Icons.verified_user_outlined,
            color: const Color(0xFF10B981),
            cardBg: cardBg,
            borderColor: borderColor,
            textMuted: textMuted,
            textPrimary: textPrimary,
          ),
        ];

        if (isDesktop) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: c,
            ))).toList(),
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: cards[0])),
                  Expanded(child: Padding(padding: const EdgeInsets.only(left: 6), child: cards[1])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: c,
            )).toList(),
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading stats: $err', style: TextStyle(color: textMuted))),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;
  final Color textPrimary;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge (36x36 rounded square, 8px radius)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          
          // Animated Count-Up Number
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (context, val, child) {
              return Text(
                val.toString(),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          
          // Label
          Text(
            label,
            style: TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
