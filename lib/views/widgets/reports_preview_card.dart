import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class ReportsPreviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final VoidCallback onViewAll;
  final VoidCallback onReportNew;

  const ReportsPreviewCard({
    super.key,
    required this.reports,
    required this.onViewAll,
    required this.onReportNew,
  });

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

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final activeGreen = const Color(0xFF16A34A);

    final previewItems = reports.take(3).toList();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Reports Tracker',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (reports.isNotEmpty)
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'View All →',
                      style: TextStyle(
                        color: activeGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (reports.isEmpty) ...[
              // Empty State
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You haven't reported any suspicious links yet.",
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onReportNew,
                      icon: const Icon(Icons.add_moderator, size: 14),
                      label: const Text('File Report', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: activeGreen,
                        side: BorderSide(color: activeGreen),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // List of latest 3 items
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: previewItems.length,
                separatorBuilder: (_, __) => Divider(color: border, height: 16),
                itemBuilder: (context, idx) {
                  final item = previewItems[idx];
                  final url = item['url'] ?? '';
                  final status = item['verification_status'] ?? 'pending';
                  final date = item['created_at'] ?? '';
                  final statusColor = _getStatusColor(status);

                  return InkWell(
                    onTap: () => context.push('/community-reports/${item['id']}'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                url,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
