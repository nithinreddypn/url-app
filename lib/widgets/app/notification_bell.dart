import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final FocusNode _buttonFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _closeDropdown();
    _buttonFocusNode.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Gesture detector to close dropdown when tapping outside
          GestureDetector(
            onTap: _closeDropdown,
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          Positioned(
            width: 360,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-360 + size.width, size.height + 8),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
                child: KeyboardListener(
                  focusNode: FocusNode()..requestFocus(),
                  onKeyEvent: (KeyEvent event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                      _closeDropdown();
                    }
                  },
                  child: _NotificationPanel(
                    onClose: _closeDropdown,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);

    final unreadCount = notificationsAsync.value?.where((item) => !item.isRead).length ?? 0;
    final tooltipText = unreadCount > 0 ? '$unreadCount unread notifications' : 'Notifications';

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        button: true,
        label: tooltipText,
        child: Focus(
          focusNode: _buttonFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
              _toggleDropdown();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Tooltip(
            message: tooltipText,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 36x36 Square Bell Button
                InkWell(
                  onTap: _toggleDropdown,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Icon(
                        _isOpen ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                
                // Red circular/pill unread badge
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBg, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

class _NotificationPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const _NotificationPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final panelBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          _NotificationHeader(
            onClose: onClose,
          ),
          
          // Separator
          Divider(color: borderColor, height: 1),

          // Notification List
          notificationsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  child: Center(
                    child: Text(
                      "You're all caught up.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(color: borderColor.withOpacity(0.5), height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return NotificationItem(
                      item: item,
                      onTap: () {
                        onClose();
                        ref.read(notificationsProvider.notifier).markAsRead(item.id);
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => NotificationDetailDialog(item: item),
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading…',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'Error loading alerts',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHeader extends ConsumerWidget {
  final VoidCallback onClose;

  const _NotificationHeader({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final items = notificationsAsync.value ?? [];
    final unreadCount = items.where((item) => !item.isRead).length;

    final hasUnread = unreadCount > 0;
    final hasItems = items.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          
          // Action Buttons
          TextButton(
            onPressed: hasUnread
                ? () {
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                    onClose();
                  }
                : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Opacity(
              opacity: hasUnread ? 1.0 : 0.4,
              child: Text(
                'Mark all as read',
                style: TextStyle(
                  color: hasUnread ? Colors.blue : textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: hasItems
                ? () {
                    ref.read(notificationsProvider.notifier).clearAll();
                    onClose();
                  }
                : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Opacity(
              opacity: hasItems ? 1.0 : 0.4,
              child: Text(
                'Clear all',
                style: TextStyle(
                  color: hasItems ? Colors.red : textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationItem extends ConsumerWidget {
  final NotificationModel item;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}m ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    
    // Background highlight for unread
    final itemBgColor = item.isRead
        ? Colors.transparent
        : (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC));

    final iconColor = item.color;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        label: '${item.title}, ${item.isRead ? 'read' : 'unread'}. ${item.message}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: itemBgColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 32x32 icon badge, rounded 6px, bordered
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                ),
                child: Icon(
                  item.icon,
                  color: iconColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),

              // Content Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          // Unread blue dot (6x6 circle)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTimeAgo(item.createdAt),
                          style: TextStyle(
                            color: textSecondary.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        if (item.priority != 'low')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.priorityLabel,
                              style: TextStyle(
                                color: item.priorityColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationDetailDialog extends ConsumerWidget {
  final NotificationModel item;

  const NotificationDetailDialog({super.key, required this.item});

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}m ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final iconColor = item.color;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                // Larger icon badge (40x40, rounded 8px)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                  ),
                  child: Icon(
                    item.icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type.toUpperCase(),
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimeAgo(item.createdAt),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              item.title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              item.message,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (item.relatedReportId != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/community-reports/${item.relatedReportId}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.activeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'View Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            'Close',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
