// LINT-STYLE REMINDER:
// Never expose third-party provider names (VirusTotal, Google Safe Browsing, OpenPhish, URLHaus, PhishTank, WHOIS, etc.) anywhere in this UI.
// Always use the single branded phrase "URL Defender Threat Intelligence" for anything sourced from the verification pipeline.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class VerifiedIntelligenceView extends StatefulWidget {
  final Map<String, dynamic> urlData;

  const VerifiedIntelligenceView({
    super.key,
    required this.urlData,
  });

  @override
  State<VerifiedIntelligenceView> createState() => _VerifiedIntelligenceViewState();
}

class _VerifiedIntelligenceViewState extends State<VerifiedIntelligenceView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = context.bg;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    final url = widget.urlData['url'] ?? '';
    final category = widget.urlData['threat_category'] ?? 'Suspicious';
    final reportsCount = widget.urlData['reporter_count'] ?? 1;
    final confidence = widget.urlData['confidence_score'] ?? 75;
    
    // Check verdict
    final verdict = (widget.urlData['verdict'] ?? 'dangerous').toString().toLowerCase();
    final isDangerous = verdict == 'dangerous' || verdict == 'malicious';
    
    final badgeColor = isDangerous ? Colors.red : Colors.green;
    final verdictTitle = isDangerous ? 'Verified Dangerous' : 'Verified Safe';
    final recText = isDangerous ? 'We recommend avoiding this website.' : 'This website is verified as safe to browse.';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Security Intelligence',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verified Threat Intelligence',
              style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Main Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          verdictTitle,
                          style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Target URL:',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    url,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    recText,
                    style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Confidence', '$confidence%'),
                      _buildMetricItem('Reports Received', '$reportsCount'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Expandable details section (provider-agnostic)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: ExpansionTile(
                title: Text(
                  'How was this verified?',
                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: textSecondary),
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isExpanded = expanded;
                  });
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                    child: Text(
                      'Verified using multiple independent security intelligence sources together with community reports and moderator review.',
                      style: TextStyle(color: textSecondary, fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
