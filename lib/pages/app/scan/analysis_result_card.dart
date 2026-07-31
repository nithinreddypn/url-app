import 'package:flutter/material.dart';
import '../../../models/url_scan_model.dart';
import '../../../models/url_lookup_result.dart';
import '../../../theme/app_theme.dart';
import 'scan_theme.dart';

/// Card showing a prior analysis result for a URL.
/// Verdict-themed: safe (emerald), suspicious (amber), dangerous (rose).
class AnalysisResultCard extends StatelessWidget {
  final UrlScanModel scan;
  final UrlLookupResult? lookupResult;
  final bool isBlocked;
  final bool isBlocking;
  final VoidCallback onBlock;
  final VoidCallback onViewReport;

  const AnalysisResultCard({
    super.key,
    required this.scan,
    this.lookupResult,
    required this.isBlocked,
    required this.isBlocking,
    required this.onBlock,
    required this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    final verdict = scan.scanResult?.toLowerCase() ?? 'safe';
    final colors = ScanTokens.verdictColors(verdict);
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final isDark = context.isDark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine grid columns based on screen width
    int infoCols;
    if (screenWidth > 1024) {
      infoCols = 5;
    } else if (screenWidth > 640) {
      infoCols = 4;
    } else {
      infoCols = 2;
    }

    // Determine verdict display
    String verdictLabel;
    IconData verdictIcon;
    switch (verdict) {
      case 'dangerous':
        verdictLabel = 'DANGEROUS';
        verdictIcon = Icons.gpp_bad_rounded;
        break;
      case 'suspicious':
        verdictLabel = 'SUSPICIOUS';
        verdictIcon = Icons.warning_amber_rounded;
        break;
      default:
        verdictLabel = 'SAFE';
        verdictIcon = Icons.verified_user_rounded;
    }

    // Get analysis data
    final analysis = lookupResult?.analysis;
    String domain = scan.scannedUrl;
    try {
      String cleanUrl = scan.scannedUrl.trim();
      if (!cleanUrl.startsWith('http://') &&
          !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      domain = Uri.parse(cleanUrl).host;
      if (domain.isEmpty) domain = scan.scannedUrl;
    } catch (_) {}

    final infoItems = <_InfoCell>[
      _InfoCell('DOMAIN', domain),
      _InfoCell('STATUS', verdictLabel),
      _InfoCell('RISK SCORE', '${scan.riskScore ?? 0}/100'),
      _InfoCell('SSL', analysis?.sslStatus ?? 'Unknown'),
      _InfoCell(
        'FIRST DETECTED',
        scan.scannedAt != null
            ? '${scan.scannedAt!.day}/${scan.scannedAt!.month}/${scan.scannedAt!.year}'
            : 'N/A',
      ),
      _InfoCell(
        'REDIRECT COUNT',
        '${analysis?.redirectCount ?? 0}',
      ),
      _InfoCell('CATEGORY', analysis?.category ?? 'Unknown'),
      _InfoCell('THREAT TYPE', scan.threatType ?? 'None'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(ScanTokens.innerRadius),
        border: Border.all(color: colors.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEADER ROW ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(verdictIcon, color: colors.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Analysis Available',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.bg,
                              borderRadius: BorderRadius.circular(
                                ScanTokens.badgeRadius,
                              ),
                              border: Border.all(
                                color: colors.accent.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              verdictLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scan.scannedAt != null
                            ? 'Last scan: ${scan.scannedAt!.day}/${scan.scannedAt!.month}/${scan.scannedAt!.year}'
                            : 'Latest verified analysis',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onViewReport,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 36),
                    foregroundColor: colors.accent,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View report',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Separator
          Divider(
            height: 1,
            color: context.border,
          ),

          // ─── INFO GRID ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: infoItems.map((item) {
                final width = (MediaQuery.of(context).size.width - 72) /
                        infoCols -
                    8;
                return SizedBox(
                  width: width.clamp(100, 300).toDouble(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.02),
                      borderRadius:
                          BorderRadius.circular(ScanTokens.inputRadius),
                      border: Border.all(color: context.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          style: ScanTokens.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ─── ACTIONS ───
          if (verdict == 'dangerous' && !isBlocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: isBlocking ? null : onBlock,
                  icon: isBlocking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.block_rounded, size: 16),
                  label: Text(
                    isBlocking ? 'Blocking…' : 'Block this URL',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ScanTokens.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(ScanTokens.inputRadius),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCell {
  final String label;
  final String value;
  const _InfoCell(this.label, this.value);
}
