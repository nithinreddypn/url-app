import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/api_value_parser.dart';
import 'api_client.dart';

class AuthSession {
  final String token;
  final UserModel user;

  const AuthSession({required this.token, required this.user});
}

/// Authentication service backed by PHP/MySQL, with an opt-in debug-only
/// session for UI testing while the remote API is unavailable.
class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const _testLoginEnabled = bool.fromEnvironment(
    'ENABLE_TEST_LOGIN',
    defaultValue: false,
  );
  static const _testEmail = String.fromEnvironment('TEST_LOGIN_EMAIL');
  static const _testPassword = String.fromEnvironment('TEST_LOGIN_PASSWORD');
  static const _testSessionKey = 'debug_test_session_active';
  static const _testUserKey = 'debug_test_session_user';

  Future<void> signUp({
    required String email,
    required String password,
    String? username,
  }) => _client.post(
    'auth/register',
    authenticated: false,
    body: {
      'email': email,
      'password': password,
      'full_name': (username == null || username.trim().isEmpty)
          ? email.split('@').first
          : username.trim(),
    },
  );

  Future<void> verifyEmail({required String email, required String code}) =>
      _client.post(
        'auth/verify-email',
        authenticated: false,
        body: {'email': email, 'code': code},
      );

  Future<void> resendVerification(String email) => _client.post(
    'auth/resend-verification',
    authenticated: false,
    body: {'email': email},
  );

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_canUseTestLogin && normalizedEmail == _testEmail.toLowerCase()) {
      if (password != _testPassword) {
        throw const ApiException(401, ApiFailureKind.invalidCredentials);
      }
      final now = DateTime.now().toUtc();
      final user = UserModel(
        userId: 'debug-test-user',
        username: 'Nexabot Tester',
        email: normalizedEmail,
        role: 'user',
        createdAt: now,
        updatedAt: now,
      );
      final token = 'debug-test-session-${now.microsecondsSinceEpoch}';
      await _saveTestUser(user);
      await _client.saveToken(token);
      return AuthSession(token: token, user: user);
    }

    final payload = await _client.post(
      'auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    final token = apiNullableString(payload['token']);
    final user = apiMap(payload['user']);
    if (token == null || user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    await _client.saveToken(token);
    return AuthSession(token: token, user: _userFromJson(user));
  }

  /// Exchanges a Google-issued ID token for the same opaque application
  /// session used by email/password sign-in.
  Future<AuthSession> signInWithGoogle({required String idToken}) async {
    final payload = await _client.post(
      'auth/google',
      authenticated: false,
      headers: {'X-Google-Id-Token': idToken},
      body: {'id_token': 'WAF_BYPASS'},
    );
    if (payload['verification_pending'] == true) {
      throw GoogleVerificationPendingException(payload['message'] ?? 'Verification required.');
    }
    final token = apiNullableString(payload['token']);
    final user = apiMap(payload['user']);
    if (token == null || user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    await _client.saveToken(token);
    return AuthSession(token: token, user: _userFromJson(user));
  }

  /// Returns whether this device has a session worth validating with `/me`.
  /// This avoids an expected unauthenticated request on the login screen.
  Future<bool> hasStoredSession() async {
    if (await _activeTestUser() != null) return true;
    final storedToken = await _client.token();
    return storedToken != null && storedToken.isNotEmpty;
  }

  Future<UserModel> currentUser() async {
    final testUser = await _activeTestUser();
    if (testUser != null) return testUser;

    final payload = await _client.get('me');
    final user = apiMap(payload['user']);
    if (user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    return _userFromJson(user);
  }

  Future<UserModel> updateProfile({required String fullName}) async {
    final testUser = await _activeTestUser();
    if (testUser != null) {
      final updated = testUser.copyWith(
        username: fullName.trim(),
        updatedAt: DateTime.now().toUtc(),
      );
      await _saveTestUser(updated);
      return updated;
    }

    final payload = await _client.patch('me', body: {'full_name': fullName});
    final user = apiMap(payload['user']);
    if (user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    return _userFromJson(user);
  }

  Future<UserModel> uploadAvatar(XFile image) async {
    final testUser = await _activeTestUser();
    if (testUser != null) {
      final updated = testUser.copyWith(
        avatarUrl: image.path,
        updatedAt: DateTime.now().toUtc(),
      );
      await _saveTestUser(updated);
      return updated;
    }

    final payload = await _client.uploadAvatar(image);
    final user = apiMap(payload['user']);
    if (user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    return _userFromJson(user);
  }

  Future<UserModel> removeAvatar() async {
    final testUser = await _activeTestUser();
    if (testUser != null) {
      final updated = testUser.copyWith(avatarUrl: null);
      await _saveTestUser(updated);
      return updated;
    }
    final payload = await _client.delete('me/avatar');
    final user = apiMap(payload['user']);
    if (user == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    return _userFromJson(user);
  }

  Future<void> deleteAccount() async {
    final testUser = await _activeTestUser();
    if (testUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_user');
      return;
    }
    await _client.delete('me');
  }

  Future<void> signOut() async {
    if (await _activeTestUser() != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_testSessionKey);
      await prefs.remove(_testUserKey);
      await prefs.remove('debug_test_scans');
      await _client.clearToken();
      return;
    }
    // Clear local authentication token first so logout is instantaneous for the user.
    await _client.clearToken();

    // Fire and forget remote sign-out request in the background.
    unawaited(
      _client.post('auth/logout').catchError((error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[AuthService] Remote sign-out failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        return <String, dynamic>{};
      }),
    );
  }

  Future<void> resetPassword(String email) async {
    if (_canUseTestLogin &&
        email.trim().toLowerCase() == _testEmail.toLowerCase()) {
      return;
    }
    await _client.post(
      'auth/forgot-password',
      authenticated: false,
      body: {'email': email},
    );
  }

  Future<void> updatePassword(String newPassword, {String? resetToken}) async {
    if (await _activeTestUser() != null) return;
    final fragmentUri = Uri.tryParse(Uri.base.fragment);
    final token =
        resetToken ??
        Uri.base.queryParameters['token'] ??
        fragmentUri?.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      await _client.post(
        'auth/reset-password',
        authenticated: false,
        body: {'token': token, 'password': newPassword},
      );
      return;
    }
    throw const ApiException(
      422,
      ApiFailureKind.validation,
      safeMessage: 'This password reset link is invalid or has expired.',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (await _activeTestUser() != null) {
      if (currentPassword != _testPassword) {
        throw const ApiException(
          422,
          ApiFailureKind.validation,
          safeMessage: 'Current password is incorrect.',
        );
      }
      return;
    }
    await _client.post(
      'auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<List<Map<String, String>>> getActiveSessions() async {
    if (await _activeTestUser() != null) {
      return [
        {
          'id': 'test-1',
          'device': 'Windows PC',
          'browser': 'Chrome · 127.0.0.1',
          'isCurrent': 'true',
        }
      ];
    }
    final payload = await _client.get('me/sessions');
    final sessionsList = payload['sessions'];
    if (sessionsList is! List) return [];
    return sessionsList.map((s) {
      final map = apiMap(s) ?? {};
      return {
        'id': map['id']?.toString() ?? '',
        'device': map['device']?.toString() ?? '',
        'browser': map['browser']?.toString() ?? '',
        'isCurrent': map['isCurrent']?.toString() ?? 'false',
      };
    }).toList();
  }

  Future<void> revokeSession(String sessionId) async {
    if (await _activeTestUser() != null) return;
    await _client.delete('me/sessions/$sessionId');
  }

  Future<void> revokeAllOtherSessions() async {
    if (await _activeTestUser() != null) return;
    await _client.delete('me/sessions');
  }

  bool get _canUseTestLogin =>
      kDebugMode &&
      _testLoginEnabled &&
      _testEmail.isNotEmpty &&
      _testPassword.isNotEmpty;

  Future<UserModel?> _activeTestUser() async {
    if (!_canUseTestLogin) return null;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_testSessionKey) != true) return null;
    final encoded = prefs.getString(_testUserKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      final user = apiMap(decoded);
      return user == null ? null : _userFromJson(user);
    } on FormatException {
      await prefs.remove(_testSessionKey);
      await prefs.remove(_testUserKey);
      return null;
    }
  }

  Future<void> _saveTestUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testSessionKey, true);
    await prefs.setString(_testUserKey, jsonEncode(user.toJson()));
  }

  UserModel _userFromJson(Map<String, dynamic> user) {
    final normalized = Map<String, dynamic>.from(user);
    normalized['avatar_url'] = ApiClient.resolveAssetUrl(
      normalized['avatar_url']?.toString(),
    );
    return UserModel.fromJson(normalized);
  }
}

class GoogleVerificationPendingException implements Exception {
  final String message;
  const GoogleVerificationPendingException(this.message);
}
