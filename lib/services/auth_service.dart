import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class AuthService {
  final _client = SupabaseConfig.client;

  /// Sign up a new user with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        // ignore: use_null_aware_elements
        if (username != null) 'username': username,
      },
    );
    return response;
  }

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get the currently authenticated user, or null if not signed in.
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Get the current session, or null if not signed in.
  Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  /// Check if a user is currently signed in.
  bool get isSignedIn => _client.auth.currentUser != null;

  /// Listen to auth state changes (sign in, sign out, token refresh, etc.).
  Stream<AuthState> onAuthStateChange() {
    return _client.auth.onAuthStateChange;
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update the current user's password.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
