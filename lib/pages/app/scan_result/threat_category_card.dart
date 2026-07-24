import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'animated_cyber_card.dart';

class ThreatCategoryCard extends StatelessWidget {
  final String? threatType;
  final int riskScore;

  const ThreatCategoryCard({
    super.key,
    required this.threatType,
    required this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    final hasThreat = threatType != null && threatType!.isNotEmpty;
    
    // Severity mapping based on risk score
    Color severityColor = context.safe;
    String severityLabel = 'CLEAN';
    
    if (hasThreat) {
      if (riskScore >= 60) {
        severityColor = context.danger;
        severityLabel = 'CRITICAL';
      } else {
        severityColor = context.warning;
        severityLabel = 'WARNING';
      }
    }

    return AnimatedCyberCard(
      accentColor: severityColor,
      semanticsLabel: 'Threat Category: ${threatType ?? 'Clean'}, Severity: $severityLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Leading Icon & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                hasThreat ? Icons.gpp_maybe_rounded : Icons.verified_user_rounded,
                size: 20,
                color: severityColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: severityColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    color: severityColor,
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
            hasThreat ? threatType!.toUpperCase() : 'CLEAN SITE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'THREAT CLASSIFICATION',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
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
              Icon(Icons.category_rounded, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CATEGORY: ${hasThreat ? "Malicious Host" : "Verified Clean"}',
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
              Icon(Icons.warning_amber_rounded, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SEVERITY SCORE: $riskScore/100',
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
