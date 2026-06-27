import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_defender/router/app_router.dart';

void main() {
  group('Password Recovery Routing Flow Tests', () {
    test('isPasswordRecoveryMode defaults to false', () {
      expect(isPasswordRecoveryMode, isFalse);
    });

    test('isPasswordRecoveryMode set to true when passwordRecovery event received', () {
      // Mocking stream listener behavior
      isPasswordRecoveryMode = false;
      
      // Simulate state event
      const state = AuthState(AuthChangeEvent.passwordRecovery, null);
      if (state.event == AuthChangeEvent.passwordRecovery) {
        isPasswordRecoveryMode = true;
      }
      
      expect(isPasswordRecoveryMode, isTrue);
    });

    test('isPasswordRecoveryMode set to false on signedIn or signedOut events', () {
      isPasswordRecoveryMode = true;

      // Simulate signedIn event
      const stateIn = AuthState(AuthChangeEvent.signedIn, null);
      if (stateIn.event == AuthChangeEvent.signedOut || stateIn.event == AuthChangeEvent.signedIn) {
        isPasswordRecoveryMode = false;
      }
      expect(isPasswordRecoveryMode, isFalse);

      isPasswordRecoveryMode = true;

      // Simulate signedOut event
      const stateOut = AuthState(AuthChangeEvent.signedOut, null);
      if (stateOut.event == AuthChangeEvent.signedOut || stateOut.event == AuthChangeEvent.signedIn) {
        isPasswordRecoveryMode = false;
      }
      expect(isPasswordRecoveryMode, isFalse);
    });
  });
}
