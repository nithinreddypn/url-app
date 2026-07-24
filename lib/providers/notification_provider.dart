import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationsProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<List<NotificationModel>>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationNotifier(service);
});

class NotificationNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationService _service;
  Timer? _pollingTimer;

  NotificationNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchNotifications();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _silentFetch();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    state = const AsyncValue.loading();
    try {
      final items = await _service.getNotifications();
      final deduped = <NotificationModel>[];
      final seenIds = <String>{};
      for (final item in items) {
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          deduped.add(item);
        }
      }
      if (mounted) {
        state = AsyncValue.data(deduped);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> _silentFetch() async {
    try {
      final items = await _service.getNotifications();
      final deduped = <NotificationModel>[];
      final seenIds = <String>{};
      for (final item in items) {
        if (!seenIds.contains(item.id)) {
          seenIds.add(item.id);
          deduped.add(item);
        }
      }
      if (mounted) {
        state = AsyncValue.data(deduped);
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    // Optimistic Update
    final current = state.value ?? [];
    final updated = current.map((item) {
      if (item.id == id) {
        return NotificationModel(
          id: item.id,
          scanId: item.scanId,
          relatedReportId: item.relatedReportId,
          type: item.type,
          title: item.title,
          message: item.message,
          severity: item.severity,
          priority: item.priority,
          category: item.category,
          readAt: DateTime.now(),
          createdAt: item.createdAt,
        );
      }
      return item;
    }).toList();
    
    state = AsyncValue.data(updated);

    try {
      await _service.markAsRead(id);
    } catch (_) {
      // Revert if failed
      _silentFetch();
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic Update
    final current = state.value ?? [];
    final updated = current.map((item) {
      return NotificationModel(
        id: item.id,
        scanId: item.scanId,
        relatedReportId: item.relatedReportId,
        type: item.type,
        title: item.title,
        message: item.message,
        severity: item.severity,
        priority: item.priority,
        category: item.category,
        readAt: item.readAt ?? DateTime.now(),
        createdAt: item.createdAt,
      );
    }).toList();

    state = AsyncValue.data(updated);

    try {
      await _service.markAllAsRead();
    } catch (_) {
      _silentFetch();
    }
  }

  Future<void> clearAll() async {
    // Optimistic Update
    state = const AsyncValue.data([]);

    try {
      await _service.clearAll();
    } catch (_) {
      _silentFetch();
    }
  }
}
