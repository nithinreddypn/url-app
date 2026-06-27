import '../models/user_model.dart';
import 'supabase_config.dart';

class UserService {
  final _client = SupabaseConfig.client;
  static const _table = 'users';

  /// Fetch a user by their user ID.
  Future<UserModel?> getUser(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Fetch a user by their email address.
  Future<UserModel?> getUserByEmail(String email) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('email', email)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Create a new user profile in the users table.
  Future<UserModel> createUser({
    required String userId,
    required String username,
    required String email,
    String role = 'user',
  }) async {
    final response = await _client.from(_table).upsert({
      'user_id': userId,
      'username': username,
      'email': email,
      'role': role,
    }).select().single();

    return UserModel.fromJson(response);
  }

  /// Update user profile fields.
  Future<UserModel> updateUser(String userId, Map<String, dynamic> updates) async {
    final response = await _client
        .from(_table)
        .update(updates)
        .eq('user_id', userId)
        .select()
        .single();

    return UserModel.fromJson(response);
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
