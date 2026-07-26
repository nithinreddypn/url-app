import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// Native Google Sign-In implementation.
///
/// The OAuth client ID is public. No OAuth client secret is stored in Flutter.
class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignInService instance = GoogleSignInService._();

  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '729107585198-2djt2sm2nho5k52cvc0itom0m1nmrkpa.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _initialization;

  /// Kept for the shared widget contract. Native authentication returns the
  /// token directly and never publishes browser events.
  Stream<String> get webIdTokens => const Stream<String>.empty();

  Future<void> initialize() => _initialization ??= _googleSignIn.initialize(
    // Android uses its registered Android OAuth client. This server client ID
    // requests an ID token whose audience the PHP API verifies.
    serverClientId: webClientId,
  );

  Future<String> signInOnNativePlatform() async {
    await initialize();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError('Google sign-in is not available on this device.');
    }

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an identity token.');
    }
    return idToken;
  }
}
