import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/api_client.dart';
import 'package:url_defender/services/login_error_handler.dart';

void main() {
  group('LoginErrorHandler', () {
    test('maps invalid credentials to review action', () {
      final result = LoginErrorHandler.fromException(
        const ApiException(401, ApiFailureKind.invalidCredentials),
      );
      expect(result.title, 'Login Failed');
      expect(result.description, 'Invalid email or password.');
      expect(result.action, LoginErrorAction.reviewCredentials);
    });

    test('maps connection failures to retry guidance', () {
      final result = LoginErrorHandler.fromException(
        const ApiException(0, ApiFailureKind.connection),
      );
      expect(result.title, 'Unable to Sign In');
      expect(result.description, contains('service could not be reached'));
      expect(result.description, isNot(contains('API_BASE_URL')));
      expect(result.action, LoginErrorAction.retry);
    });

    test('maps disabled accounts to safe support guidance', () {
      final result = LoginErrorHandler.fromException(
        const ApiException(403, ApiFailureKind.accountDisabled),
      );
      expect(result.title, 'Account Disabled');
      expect(result.description, contains('contact support'));
      expect(result.action, LoginErrorAction.dismiss);
    });

    test('maps timeout to retry', () {
      final result = LoginErrorHandler.fromException(
        TimeoutException('internal endpoint timeout'),
      );
      expect(result.title, 'Request Timed Out');
      expect(result.actionLabel, 'Try Again');
    });

    test('never returns unknown technical details', () {
      final result = LoginErrorHandler.fromException(
        Exception(
          'SQLSTATE PHP warning at http://127.0.0.1:8000 with stack trace',
        ),
      );
      final visible = '${result.title} ${result.description}';
      expect(visible, isNot(contains('SQLSTATE')));
      expect(visible, isNot(contains('PHP')));
      expect(visible, isNot(contains('127.0.0.1')));
      expect(visible, isNot(contains('stack trace')));
    });

    test('maps HTTP status without a response body', () {
      expect(
        LoginErrorHandler.fromHttpStatus(503).description,
        'Sign-in is temporarily unavailable. Please try again later.',
      );
    });

    test('Google failures use one safe Google-specific response', () {
      final result = LoginErrorHandler.fromGoogleException(
        Exception(
          'GSI 403 client_id at http://localhost:8080 with raw response',
        ),
      );

      expect(result.title, 'Google Sign-In Unavailable');
      expect(
        result.description,
        'Unable to complete Google Sign-In. Error details: Exception: GSI 403 client_id at http://localhost:8080 with raw response',
      );
      expect(result.actionLabel, 'Use Email');
      expect(result.action, LoginErrorAction.dismiss);
    });
  });
}
