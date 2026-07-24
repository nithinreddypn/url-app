import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'animated_cyber_card.dart';

class ThreatIntelligenceCard extends StatelessWidget {
  final int blacklists;

  const ThreatIntelligenceCard({
    super.key,
    required this.blacklists,
  });

  @override
  Widget build(BuildContext context) {
    final hasBlacklist = blacklists > 0;
    final statusColor = hasBlacklist ? context.danger : context.safe;
    final statusLabel = hasBlacklist ? 'FLAGGED' : 'VERIFIED CLEAN';

    return AnimatedCyberCard(
      accentColor: statusColor,
      semanticsLabel: 'Threat Intelligence: $blacklists flagged engines, status: $statusLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Leading Icon & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.analytics_rounded,
                size: 20,
                color: statusColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Hero text
          Text(
            '$blacklists / 10',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'THREAT FEED DETECTIONS',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          // Engine dot cluster visualization (10 engines total)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(10, (index) {
              final isFlagged = index < blacklists;
              final dotColor = isFlagged ? context.danger : context.safe;
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4.5),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
          const Spacer(),
          // Divider
          Container(
            height: 1,
            color: context.border.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          // Metadata rows
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasBlacklist
                      ? 'WARNING: DETECTED BY $blacklists REPUTATION FEEDS'
                      : 'CLEAN: PASSED ALL BLACKLIST CHECKS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.update_rounded, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LAST UPDATE: RELIABLE REAL-TIME DATA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
