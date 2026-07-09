import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/blocked_url_model.dart';

class BlockedUrlService {
  static final List<BlockedUrlModel> _localBlockedUrls = [];

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedJson = prefs.getString('local_blocked_urls');
      if (blockedJson != null) {
        final decoded = jsonDecode(blockedJson) as List;
        final loadedBlocked = <BlockedUrlModel>[];
        for (final item in decoded) {
          try {
            if (item is Map<String, dynamic>) {
              loadedBlocked.add(BlockedUrlModel.fromJson(item));
            } else if (item is Map) {
              loadedBlocked.add(BlockedUrlModel.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            print('Error parsing individual blocked URL: $e');
          }
        }
        _localBlockedUrls.clear();
        _localBlockedUrls.addAll(loadedBlocked);
      }
    } catch (e) {
      print('Error initializing local blocked URLs: $e');
    }
    _initialized = true;
  }

  static Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedJson = jsonEncode(_localBlockedUrls.map((b) => b.toJson()).toList());
      await prefs.setString('local_blocked_urls', blockedJson);
    } catch (e) {
      print('Error saving local blocked URLs: $e');
    }
  }

  /// Block a URL for a specific user.
  Future<BlockedUrlModel> blockUrl({
    required String userId,
    required String url,
    String? reason,
  }) async {
    await _ensureInitialized();
    final newBlocked = BlockedUrlModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      url: url,
      reason: reason,
      blockedAt: DateTime.now(),
    );

    _localBlockedUrls.insert(0, newBlocked);
    await _saveToPrefs();
    return newBlocked;
  }

  /// Unblock a URL (delete the blocked entry).
  Future<void> unblockUrl(String id, {required String userId}) async {
    await _ensureInitialized();
    _localBlockedUrls.removeWhere((blocked) => blocked.id == id && blocked.userId == userId);
    await _saveToPrefs();
  }

  /// Unblock a URL by user ID and URL string.
  Future<void> unblockUrlByValue({
    required String userId,
    required String url,
  }) async {
    await _ensureInitialized();
    _localBlockedUrls.removeWhere((blocked) => blocked.url == url && blocked.userId == userId);
    await _saveToPrefs();
  }

  /// Get all blocked URLs for a specific user.
  Future<List<BlockedUrlModel>> getBlockedUrls(String userId) async {
    await _ensureInitialized();
    return _localBlockedUrls.where((blocked) => blocked.userId == userId).toList();
  }

  /// Check if a URL is blocked for a specific user.
  Future<bool> isUrlBlocked({
    required String userId,
    required String url,
  }) async {
    await _ensureInitialized();
    return _localBlockedUrls.any((blocked) => blocked.url == url && blocked.userId == userId);
  }

  /// Get the count of blocked URLs for a user.
  Future<int> getBlockedCount(String userId) async {
    await _ensureInitialized();
    return _localBlockedUrls.where((blocked) => blocked.userId == userId).length;
  }

  /// Listen to real-time blocked URL changes for a user.
  Stream<List<Map<String, dynamic>>> onBlockedUrlChanges(String userId) async* {
    await _ensureInitialized();
    yield _localBlockedUrls
        .where((blocked) => blocked.userId == userId)
        .map((blocked) => blocked.toJson())
        .toList();
  }
}
