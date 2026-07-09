class AuthService {
  static String? _typedEmail;
  static String? _typedUsername;

  static String get typedEmail => _typedEmail ?? '';
  static String get typedUsername => _typedUsername ?? '';

  static set typedEmail(String val) => _typedEmail = val;
  static set typedUsername(String val) => _typedUsername = val;

  /// Sign up a new user with email and password (mocked client-side).
  Future<dynamic> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    _typedEmail = email;
    _typedUsername = username ?? email.split('@').first;
    return null;
  }

  /// Sign in with email and password (mocked client-side).
  Future<dynamic> signIn({
    required String email,
    required String password,
  }) async {
    _typedEmail = email;
    _typedUsername = email.split('@').first;
    return null;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    _typedEmail = null;
    _typedUsername = null;
  }

  /// Check if a user is currently signed in.
  bool get isSignedIn => _typedEmail != null;

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    // Mock reset password
  }

  /// Update the current user's password.
  Future<dynamic> updatePassword(String newPassword) async {
    return null;
  }
}
