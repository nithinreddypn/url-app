import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

/// Browser-only Google Sign-In implementation.
///
/// This file deliberately has no `serverClientId` argument because the Google
/// web plugin rejects it. Conditional exports keep the native initializer out
/// of the compiled web application.
class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignInService instance = GoogleSignInService._();

  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '729107585198-2djt2sm2nho5k52cvc0itom0m1nmrkpa.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final StreamController<String> _webIdTokens =
      StreamController<String>.broadcast();

  Future<void>? _initialization;

  Stream<String> get webIdTokens => _webIdTokens.stream;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final idToken = event.user.authentication.idToken;
        if (idToken != null && idToken.isNotEmpty) {
          _webIdTokens.add(idToken);
        } else {
          _webIdTokens.addError(
            StateError('Google did not return an identity token.'),
          );
        }
      }
    }, onError: _webIdTokens.addError);

    await _googleSignIn.initialize(clientId: webClientId);
  }

  Future<String> signInOnNativePlatform() {
    throw UnsupportedError(
      'Browser sign-in must use the Google-rendered button.',
    );
  }
}
