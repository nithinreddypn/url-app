import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import '../../../models/user_model.dart';

class ActivityEvent {
  final String kind;
  final String label;
  final String? detail;
  final DateTime timestamp;

  ActivityEvent({
    required this.kind,
    required this.label,
    this.detail,
    required this.timestamp,
  });
}

class ActivityLog extends ConsumerWidget {
  const ActivityLog({super.key});

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  IconData _getEventIcon(String kind) {
    switch (kind) {
      case 'login': return Icons.person_outline_rounded;
      case 'logout': return Icons.logout_rounded;
      case 'password_changed': return Icons.key_rounded;
      case 'email_changed': return Icons.mail_outline_rounded;
      case 'mfa_enabled': return Icons.security_rounded;
      case 'mfa_disabled': return Icons.gpp_maybe_rounded;
      case 'account_created': return Icons.celebration_rounded;
      case 'profile_updated': return Icons.edit_rounded;
      case 'avatar_uploaded': return Icons.add_a_photo_rounded;
      case 'avatar_removed': return Icons.no_photography_rounded;
      case 'data_deleted': return Icons.delete_outline_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getEventColor(String kind) {
    switch (kind) {
      case 'login':
      case 'account_created':
        return Colors.blue;
      case 'password_changed':
      case 'mfa_enabled':
      case 'profile_updated':
      case 'avatar_uploaded':
      case 'email_changed':
        return const Color(0xFF10B981);
      case 'mfa_disabled':
      case 'avatar_removed':
        return Colors.amber;
      case 'logout':
      case 'data_deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final List<ActivityEvent> events = [];

    if (user != null) {
      // 1. Account Created Event
      if (user.createdAt != null) {
        events.add(ActivityEvent(
          kind: 'account_created',
          label: 'Account created',
          detail: 'Welcome to URL Defender',
          timestamp: user.createdAt!,
        ));
      }

      // 2. Profile Updated Event (if updatedAt is after createdAt)
      if (user.updatedAt != null && user.createdAt != null && user.updatedAt!.isAfter(user.createdAt!.add(const Duration(seconds: 5)))) {
        events.add(ActivityEvent(
          kind: 'profile_updated',
          label: 'Profile details updated',
          detail: 'Username or settings changed',
          timestamp: user.updatedAt!,
        ));
      }

      // 3. Avatar Upload Event
      if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
        events.add(ActivityEvent(
          kind: 'avatar_uploaded',
          label: 'Avatar image updated',
          detail: 'Profile picture uploaded',
          timestamp: user.updatedAt ?? user.createdAt ?? DateTime.now(),
        ));
      }

      // 4. Mock Login Session Event
      events.add(ActivityEvent(
        kind: 'login',
        label: 'Login session established',
        detail: 'IP: 127.0.0.1 (Windows PC)',
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      ));
    }

    // Sort by timestamp DESC
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Take top 8
    final displayEvents = events.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          Text(
            'Recent Activity',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          if (displayEvents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, style: BorderStyle.solid),
              ),
              child: Center(
                child: Text(
                  'No account activity recorded yet.',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayEvents.length,
              separatorBuilder: (_, __) => Divider(color: borderColor.withOpacity(0.5), height: 24),
              itemBuilder: (context, idx) {
                final event = displayEvents[idx];
                final evColor = _getEventColor(event.kind);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: evColor.withOpacity(0.1),
                        border: Border.all(color: evColor.withOpacity(0.3)),
                      ),
                      child: Icon(
                        _getEventIcon(event.kind),
                        color: evColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.label,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (event.detail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.detail!,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    Text(
                      _formatTimeAgo(event.timestamp),
                      style: TextStyle(
                        color: textSecondary.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
