import 'api_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  final ApiClient _client = ApiClient();

  Future<List<NotificationModel>> getNotifications() async {
    final payload = await _client.get('notifications');
    final items = payload['items'] as List?;
    if (items == null) return [];
    return items.map((item) => NotificationModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> markAsRead(String id) async {
    await _client.patch('notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _client.post('notifications/read-all');
  }

  Future<void> clearAll() async {
    await _client.delete('notifications');
  }
}
