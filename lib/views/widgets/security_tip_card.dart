import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SecurityTipCard extends StatelessWidget {
  const SecurityTipCard({super.key});

  static final List<Map<String, String>> _safetyTips = [
    {
      'title': 'OTP Phishing Safety',
      'tip': 'Never enter your OTP or passwords on websites received through SMS or WhatsApp links.',
      'detail': 'Legitimate organizations and banks will never send you a direct link to ask for an OTP (One-Time Password) or netbanking passwords. If you receive such a message, it is almost certainly a credential harvesting scam. Always navigate directly to the netbanking site.',
    },
    {
      'title': 'Verify Banking URLs',
      'tip': 'Always double-check the domain name of banking sites. Secure sites use HTTPS and match spelling exactly.',
      'detail': 'Scammers register domains that look highly similar to real banks (e.g., sbi-secure-login.com instead of sbi.co.in). Look closely at the browser address bar. Check for spelling typos, extra hyphens, or unusual subdomains.',
    },
    {
      'title': 'Urgency Warning Signs',
      'tip': 'Be suspicious of urgent alerts claiming your account is locked. Navigate directly to the official site instead.',
      'detail': 'Threat actors try to create a false sense of panic (e.g. "Your account will be suspended in 2 hours!"). This panic prevents logical checks. Remain calm, ignore links in the warning, and contact support through their verified channel.',
    },
    {
      'title': 'Pre-Scan Unknown Links',
      'tip': 'Use URL Defender to scan any suspicious links before clicking them in emails or social media posts.',
      'detail': 'Whenever you receive an unsolicited link via email, message, or social media, copy the link and run it through the URL Defender scanner first. It runs automated AI analysis and cross-checks threat databases to ensure you stay secure.',
    },
    {
      'title': 'Malicious Attachments',
      'tip': 'Avoid downloading attachments from unrecognized senders or unexpected package delivery messages.',
      'detail': 'Malware is often delivered via ZIP files, PDF invoices, or macro-enabled Excel sheets in phishing emails claiming to be parcel tracking notices (DHL, FedEx, etc.). Do not open files unless you are positive of the source.',
    },
  ];

  int _getDayOfYear() {
    final now = DateTime.now();
    final beginningOfYr = DateTime(now.year, 1, 1);
    return now.difference(beginningOfYr).inDays;
  }

  void _showTipDetails(BuildContext context, Map<String, String> tip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.lightbulb_circle, color: Color(0xFF16A34A), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    tip['title']!,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tip['tip']!,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tip['detail']!,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: This feature is previewed using offline local resources. No backend tips endpoint is currently deployed on the server.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    // Get deterministic index
    final dayOfYear = _getDayOfYear();
    final tipIndex = dayOfYear % _safetyTips.length;
    final tip = _safetyTips[tipIndex];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: border),
      ),
      color: cardBg,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF16A34A), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Daily Security Tip (Offline Preview - Backend Gap)',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip['tip']!,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => _showTipDetails(context, tip),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Learn More →',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
}
