import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserService {
  static final List<UserModel> _localUsers = [];

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('local_users');
      if (usersJson != null) {
        final decoded = jsonDecode(usersJson) as List;
        _localUsers.clear();
        _localUsers.addAll(decoded.map((json) => UserModel.fromJson(json as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error initializing local users: $e');
    }
    _initialized = true;
  }

  static Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = jsonEncode(_localUsers.map((u) => u.toJson()).toList());
      await prefs.setString('local_users', usersJson);
    } catch (e) {
      print('Error saving local users: $e');
    }
  }

  /// Fetch a user by their user ID.
  Future<UserModel?> getUser(String userId) async {
    await _ensureInitialized();
    try {
      return _localUsers.firstWhere((u) => u.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Fetch a user by their email address.
  Future<UserModel?> getUserByEmail(String email) async {
    await _ensureInitialized();
    try {
      return _localUsers.firstWhere((u) => u.email.toLowerCase() == email.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Create a new user profile in the users table.
  Future<UserModel> createUser({
    required String userId,
    required String username,
    required String email,
    String role = 'user',
  }) async {
    await _ensureInitialized();
    final newUser = UserModel(
      userId: userId,
      username: username,
      email: email,
      isPremium: false,
      role: role,
    );
    _localUsers.removeWhere((u) => u.userId == userId);
    _localUsers.add(newUser);
    await _saveToPrefs();
    return newUser;
  }

  /// Update user profile fields.
  Future<UserModel> updateUser(String userId, Map<String, dynamic> updates) async {
    await _ensureInitialized();
    final userIdx = _localUsers.indexWhere((u) => u.userId == userId);
    if (userIdx == -1) {
      // Create user if not found
      return await createUser(
        userId: userId,
        username: updates['username'] as String? ?? 'User',
        email: updates['email'] as String? ?? '',
        role: updates['role'] as String? ?? 'user',
      );
    }

    final user = _localUsers[userIdx];
    final updated = UserModel(
      userId: user.userId,
      username: updates['username'] as String? ?? user.username,
      email: updates['email'] as String? ?? user.email,
      isPremium: updates['is_premium'] as bool? ?? user.isPremium,
      lifetimeScanCount: updates['lifetime_scan_count'] as int? ?? user.lifetimeScanCount,
      blockedList: updates['blocked_list'] != null 
          ? List<String>.from(updates['blocked_list'] as Iterable) 
          : user.blockedList,
      role: updates['role'] as String? ?? user.role,
      createdAt: user.createdAt,
    );
    _localUsers[userIdx] = updated;
    await _saveToPrefs();
    return updated;
  }

  /// Update the user's blocked list.
  Future<UserModel> updateBlockedList(String userId, List<String> blockedList) async {
    return await updateUser(userId, {'blocked_list': blockedList});
  }

  /// Add a URL to the user's blocked list.
  Future<UserModel> addToBlockedList(String userId, String url) async {
    final user = await getUser(userId);
    if (user == null) throw Exception('User not found');

    final updatedList = [...user.blockedList, url];
    return await updateBlockedList(userId, updatedList);
  }

  /// Remove a URL from the user's blocked list.
  Future<UserModel> removeFromBlockedList(String userId, String url) async {
    final user = await getUser(userId);
    if (user == null) throw Exception('User not found');

    final updatedList = user.blockedList.where((u) => u != url).toList();
    return await updateBlockedList(userId, updatedList);
  }
}
