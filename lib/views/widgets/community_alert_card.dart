import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CommunityAlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final Function(String id) onDismiss;
  final VoidCallback onTap;

  const CommunityAlertCard({
    super.key,
    required this.alert,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = context.cardBg;
    final border = context.border;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    final id = alert['id']?.toString() ?? UniqueKey().toString();
    final type = alert['type'] ?? 'threat_alert';
    final title = alert['title'] ?? 'Security Alert';
    final message = alert['message'] ?? '';
    final time = alert['created_at'] ?? '';

    // Determine theme color based on threat level
    final isCritical = type == 'community_verified' || type == 'threat_alert';
    final accentColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    final bgFill = accentColor.withOpacity(0.05);

    return Dismissible(
      key: Key('alert-dismiss-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDismiss(id);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Acknowledge',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentColor.withOpacity(0.3), width: 1.5),
        ),
        color: cardBg,
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight icon badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCritical ? Icons.gpp_bad : Icons.info_outline,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color: textSecondary.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Swipe left to acknowledge',
                        style: TextStyle(
                          color: textSecondary.withOpacity(0.4),
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
