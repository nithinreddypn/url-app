import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class VerificationTimeline extends StatelessWidget {
  final List<dynamic> timeline;

  const VerificationTimeline({super.key, required this.timeline});

  IconData _getStepIcon(String step, String status) {
    if (status == 'completed') {
      return Icons.check_circle;
    }
    switch (step) {
      case 'submitted':
        return Icons.publish;
      case 'queued':
        return Icons.queue;
      case 'verification':
        return Icons.query_stats;
      case 'admin_review':
        return Icons.rate_review;
      case 'decision':
        return Icons.gpp_maybe;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getStepColor(BuildContext context, String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'active':
        return context.activeAccent;
      default:
        return context.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final border = context.border;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final step = timeline[index];
        final stepKey = step['step'] as String;
        final title = step['title'] as String;
        final status = step['status'] as String;
        final timestamp = step['timestamp'] as String?;
        final confidence = step['confidence'] as int?;

        final color = _getStepColor(context, status);
        final icon = _getStepIcon(stepKey, status);
        final isLast = index == timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon & line column
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: status == 'completed'
                        ? Colors.green.withOpacity(0.1)
                        : (status == 'active'
                            ? context.activeAccent.withOpacity(0.1)
                            : Colors.transparent),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: status == 'active' ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: status == 'completed' ? Colors.green : border,
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Content column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: status == 'active'
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    if (confidence != null && stepKey == 'verification') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Security Scan Confidence: $confidence%',
                        style: TextStyle(
                          color: confidence >= 75
                              ? Colors.red
                              : (confidence >= 40 ? Colors.orange : Colors.green),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
