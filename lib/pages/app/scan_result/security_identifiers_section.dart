import 'package:flutter/material.dart';
import '../../../models/url_scan_model.dart';
import '../../../theme/app_theme.dart';
import 'ssl_certificate_card.dart';
import 'domain_age_card.dart';
import 'threat_category_card.dart';
import 'threat_intelligence_card.dart';

class SecurityIdentifiersSection extends StatelessWidget {
  final UrlScanModel scan;
  final String ageText;
  final String sslText;
  final bool isSslValid;
  final int blacklists;

  const SecurityIdentifiersSection({
    super.key,
    required this.scan,
    required this.ageText,
    required this.sslText,
    required this.isSslValid,
    required this.blacklists,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Identifiers',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount = 1;
            double childAspectRatio = 1.6;

            if (width > 1024) {
              crossAxisCount = 4;
              childAspectRatio = 1.35;
            } else if (width > 640) {
              crossAxisCount = 2;
              childAspectRatio = 1.45;
            } else {
              crossAxisCount = 1;
              childAspectRatio = 1.8;
            }

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                SslCertificateCard(sslText: sslText, isValid: isSslValid),
                DomainAgeCard(
                  ageText: ageText,
                  isHighRisk: (scan.riskScore ?? 0) >= 60,
                  riskScore: scan.riskScore ?? 0,
                ),
                ThreatCategoryCard(
                  threatType: scan.threatType,
                  riskScore: scan.riskScore ?? 0,
                ),
                ThreatIntelligenceCard(blacklists: blacklists),
              ],
            );
          },
        ),
      ],
    );
  }
}
