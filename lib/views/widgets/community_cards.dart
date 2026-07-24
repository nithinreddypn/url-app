import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../services/community_threat_service.dart';
import '../../services/api_client.dart';
import '../../providers/app_providers.dart';
import 'package:go_router/go_router.dart';
import 'threat_status_badge.dart';

class IntelligentThreatReportCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const IntelligentThreatReportCard({
    super.key,
    required this.data,
    this.onTap,
  });

  @override
  ConsumerState<IntelligentThreatReportCard> createState() => _IntelligentThreatReportCardState();
}

class _IntelligentThreatReportCardState extends ConsumerState<IntelligentThreatReportCard> {
  bool _voting = false;

  Future<void> _vote(String type) async {
    setState(() {
      _voting = true;
    });
    try {
      final service = ref.read(communityThreatServiceProvider);
      final reportId = widget.data['id'] ?? widget.data['threat_id'] ?? '';
      await service.submitVote(reportId: reportId, voteType: type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for voting! Verification is being computed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = (e is ApiException) ? (e.safeMessage ?? e.toString()) : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _voting = false;
        });
      }
    }
  }

  Color _getCardBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
      case 'high_risk':
        return const Color(0xFFEF4444); // Red
      case 'pending':
      case 'queued':
        return const Color(0xFFEAB308); // Yellow
      case 'needs_review':
        return const Color(0xFFF97316); // Orange
      default:
        return const Color(0xFF94A3B8); // Gray
    }
  }

  Color _getCardShadowColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
      case 'high_risk':
        return const Color(0xFFEF4444).withValues(alpha: 0.08);
      case 'pending':
      case 'queued':
        return const Color(0xFFEAB308).withValues(alpha: 0.05);
      case 'needs_review':
        return const Color(0xFFF97316).withValues(alpha: 0.06);
      default:
        return Colors.transparent;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
      case 'high_risk':
        return 'This URL has been verified as malicious. Avoid opening this website. Community members and multiple threat intelligence sources have confirmed this threat.';
      case 'pending':
      case 'queued':
        return 'Reported by the community. Verification is currently in progress. Please remain cautious. We\'ll notify you when verification completes.';
      case 'needs_review':
        return 'Awaiting final review from administrative staff.';
      default:
        return 'No malicious activity was confirmed. Thank you for helping improve URL Defender.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeAccent = context.activeAccent;

    final url = widget.data['url'] ?? '';
    final category = widget.data['threat_category'] ?? 'Suspicious';
    final reporter = widget.data['reporter_name'] ?? 'Anonymous';
    final status = widget.data['verification_status'] ?? 'pending';
    final confidence = widget.data['confidence_score'] ?? 0;
    final reportCount = widget.data['report_count'] ?? 1;
    final createdAt = widget.data['created_at'] ?? 'Recently';
    final lastActivity = widget.data['last_reported_at'] ?? createdAt;
    
    final confirmVotes = widget.data['confirm_votes'] ?? 0;
    final safeVotes = widget.data['safe_votes'] ?? 0;

    final borderClr = _getCardBorderColor(status);
    final shadowClr = _getCardShadowColor(status);
    final msg = _getStatusMessage(status);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderClr.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowClr,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Status Badge + Category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ThreatStatusBadge(status: status),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.toString().toUpperCase(),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Threat URL
            Text(
              url,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Reporter & Activity details
            Row(
              children: [
                Text(
                  'By $reporter • Reports: $reportCount',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  'Confidence: $confidence%',
                  style: TextStyle(
                    color: confidence >= 75
                        ? Colors.red
                        : (confidence >= 45 ? Colors.orange : Colors.green),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Warning/Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: borderClr.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderClr.withValues(alpha: 0.1)),
              ),
              child: Text(
                msg,
                style: TextStyle(
                  color: textPrimary.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer / Quick Votes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.thumb_up_outlined, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text('$confirmVotes', style: TextStyle(color: textSecondary, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.thumb_down_outlined, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text('$safeVotes', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _voting ? null : () => _vote('confirm_threat'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security, size: 12),
                          SizedBox(width: 4),
                          Text('Confirm Dangerous', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _voting ? null : () => _vote('looks_safe'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user, size: 12),
                          SizedBox(width: 4),
                          Text('Looks Safe', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legacy Wrapper Compatibility Cards ───

class CommunityIntelligenceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String reportId;

  const CommunityIntelligenceCard({
    super.key,
    required this.data,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    // Map existing structure to match widget
    final Map<String, dynamic> mappedData = Map.from(data);
    mappedData['id'] = reportId;
    mappedData['verification_status'] = 'approved'; // It's verified community card
    
    return IntelligentThreatReportCard(
      data: mappedData,
      onTap: () {
        if (mappedData['url_hash'] != null) {
          context.push('/community-reports/${mappedData['url_hash']}');
        } else if (reportId.isNotEmpty) {
          context.push('/community-reports/$reportId');
        }
      },
    );
  }
}

class PendingCommunityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const PendingCommunityCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> mappedData = Map.from(data);
    mappedData['verification_status'] = 'pending'; // Pending verification card
    
    return IntelligentThreatReportCard(
      data: mappedData,
      onTap: () {
        final id = mappedData['id'] ?? mappedData['threat_id'];
        if (id != null) {
          context.push('/community-reports/status/$id');
        }
      },
    );
  }
}
