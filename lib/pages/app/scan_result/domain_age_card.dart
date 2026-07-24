import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'animated_cyber_card.dart';

class DomainAgeCard extends StatelessWidget {
  final String ageText;
  final bool isHighRisk;
  final int riskScore;

  const DomainAgeCard({
    super.key,
    required this.ageText,
    required this.isHighRisk,
    required this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    // Determine risk level based on score
    final Color riskColor = isHighRisk 
        ? context.danger 
        : (riskScore >= 30 ? context.warning : context.safe);
    final String riskLabel = isHighRisk 
        ? 'HIGH RISK' 
        : (riskScore >= 30 ? 'MEDIUM RISK' : 'LOW RISK');

    final String reputation = isHighRisk 
        ? 'Untrusted' 
        : (riskScore >= 30 ? 'Suspicious' : 'Established');

    // Calculate indicator progress (older domain = lower risk = higher safe progress)
    final double progressValue = (100 - riskScore).clamp(0, 100) / 100.0;

    return AnimatedCyberCard(
      accentColor: riskColor,
      semanticsLabel: 'Domain Age: $ageText, Risk level: $riskLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Leading Icon & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: riskColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: riskColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Hero element: Circular radial indicator with domain age centered
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 72,
              width: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background ring
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 5.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.border.withOpacity(0.4),
                      ),
                    ),
                  ),
                  // Progress arc
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: progressValue,
                      strokeWidth: 5.5,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                    ),
                  ),
                  // Inner text showing domain age
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        ageText.split(' ').first,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Label text below progress indicator
          Align(
            alignment: Alignment.center,
            child: Text(
              ageText.contains('ago')
                  ? ageText.split(' ').skip(1).join(' ').toUpperCase()
                  : 'REGISTRATION AGE',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
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
              Icon(Icons.history, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'REGISTERED: $ageText',
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
              Icon(Icons.shield_outlined, size: 11, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'REPUTATION: $reputation',
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
