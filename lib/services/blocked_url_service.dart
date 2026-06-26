import '../models/blocked_url_model.dart';
import 'supabase_config.dart';

class BlockedUrlService {
  final _client = SupabaseConfig.client;
  static const _table = 'blocked_urls';

  /// Block a URL for a specific user.
  Future<BlockedUrlModel> blockUrl({
    required String userId,
    required String url,
    String? reason,
  }) async {
    final response = await _client.from(_table).insert({
      'user_id': userId,
      'url': url,
      'reason': reason,
    }).select().single();

    return BlockedUrlModel.fromJson(response);
  }

  /// Unblock a URL (delete the blocked entry).
  Future<void> unblockUrl(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Unblock a URL by user ID and URL string.
  Future<void> unblockUrlByValue({
    required String userId,
    required String url,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('url', url);
  }

  /// Get all blocked URLs for a specific user.
  Future<List<BlockedUrlModel>> getBlockedUrls(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('blocked_at', ascending: false);

    return (response as List)
        .map((json) => BlockedUrlModel.fromJson(json))
        .toList();
  }

  /// Get all blocked URLs for the entire community.
  Future<List<BlockedUrlModel>> getAllBlockedUrls() async {
    final response = await _client
        .from(_table)
        .select()
        .order('blocked_at', ascending: false);

    return (response as List)
        .map((json) => BlockedUrlModel.fromJson(json))
        .toList();
  }

  /// Check if a URL is blocked for a specific user.
  Future<bool> isUrlBlocked({
    required String userId,
    required String url,
  }) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('url', url)
        .maybeSingle();

    return response != null;
  }

  /// Get the count of blocked URLs for a user.
  Future<int> getBlockedCount(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId);

    return (response as List).length;
  }

  /// Listen to real-time blocked URL changes for a user.
  Stream<List<Map<String, dynamic>>> onBlockedUrlChanges(String userId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('blocked_at', ascending: false);
  }
}
