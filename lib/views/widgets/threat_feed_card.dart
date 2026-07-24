import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'threat_status_badge.dart';

class ThreatFeedCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final int index;

  const ThreatFeedCard({
    super.key,
    required this.data,
    required this.onTap,
    required this.index,
  });

  @override
  State<ThreatFeedCard> createState() => _ThreatFeedCardState();
}

class _ThreatFeedCardState extends State<ThreatFeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final status = widget.data['verification_status'] ?? 'pending';
    if (_isPendingState(status)) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ThreatFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.data['verification_status'] ?? 'pending';
    final oldStatus = oldWidget.data['verification_status'] ?? 'pending';
    if (status != oldStatus) {
      if (_isPendingState(status)) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool _isPendingState(String status) {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'needs_review' || s == 'queued';
  }

  Color _getStatusColor(String status) {
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

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null) return 'recently';
    try {
      final parsed = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(parsed);
      if (diff.isNegative || diff.inSeconds < 5) return 'just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    final url = widget.data['url'] ?? '';
    final category = widget.data['threat_category'] ?? 'Suspicious';
    final status = widget.data['verification_status'] ?? 'pending';
    final confidence = widget.data['confidence_score'] ?? 0;
    final reportCount = widget.data['report_count'] ?? 1;
    final timeAgo = _formatRelativeTime(widget.data['created_at']);

    final statusColor = _getStatusColor(status);
    final isPending = _isPendingState(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 4.5),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Status Indicator / Dot & Category Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isPending)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _pulseAnimation.value,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Threat URL (Hero Target)
              Hero(
                tag: 'threat-url-${widget.data['id'] ?? widget.data['threat_id']}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    url,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Footer Metadata Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reports: $reportCount • $timeAgo',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                  if (!isPending)
                    Text(
                      'Confidence: $confidence%',
                      style: TextStyle(
                        color: confidence >= 75
                            ? Colors.red
                            : (confidence >= 45 ? Colors.orange : Colors.green),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Scan In Progress',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
