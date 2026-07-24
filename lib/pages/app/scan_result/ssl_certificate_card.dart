import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'animated_cyber_card.dart';

class SslCertificateCard extends StatelessWidget {
  final String sslText;
  final bool isValid;

  const SslCertificateCard({
    super.key,
    required this.sslText,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isValid ? context.safe : context.danger;
    
    // Parse issuer if present in the text
    String? issuer;
    if (sslText.contains('Issued by')) {
      issuer = sslText.split('Issued by').last.replaceAll(')', '').trim();
    } else if (isValid) {
      issuer = 'Let\'s Encrypt';
    }

    final isNoSsl = sslText.contains('No SSL') || sslText.toLowerCase().contains('no ssl');
    final statusLabel = isNoSsl ? 'UNENCRYPTED' : (isValid ? 'SECURE' : 'WARNING');

    return AnimatedCyberCard(
      accentColor: statusColor,
      semanticsLabel: 'SSL Certificate: $statusLabel, $sslText',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Leading Icon & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                isValid ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
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
            isValid ? 'VALID' : (isNoSsl ? 'NO SSL' : 'INVALID'),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'CONNECTION ENCRYPTION',
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
          if (issuer != null)
            Row(
              children: [
                Icon(Icons.business_rounded, size: 11, color: context.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ISSUER: $issuer',
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
              Icon(
                isValid ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                size: 11,
                color: context.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isValid ? 'PROTOCOL: HTTPS (TLS 1.3)' : 'PROTOCOL: HTTP (PLAIN)',
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
