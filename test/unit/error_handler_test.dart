import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/api_client.dart';
import 'package:url_defender/services/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    test('never exposes a technical unknown exception', () {
      final error = ErrorHandler.handle(
        Exception('SQLSTATE[HY000] localhost API_BASE_URL connection refused'),
      );

      expect(error.title, 'Something Went Wrong');
      expect(error.message, 'Something went wrong. Please try again.');
      expect(error.message, isNot(contains('SQLSTATE')));
      expect(error.message, isNot(contains('localhost')));
      expect(error.message, isNot(contains('API_BASE_URL')));
    });

    test('maps connection failures without assuming the internet is down', () {
      final error = ErrorHandler.handle(
        const ApiException(0, ApiFailureKind.connection),
      );

      expect(error.title, 'Unable to Connect');
      expect(error.message, contains('Unable to reach the service'));
      expect(error.message, isNot(contains('API_BASE_URL')));
      expect(error.canRetry, isTrue);
    });

    test('maps invalid credentials without backend details', () {
      final error = ErrorHandler.handle(
        const ApiException(401, ApiFailureKind.invalidCredentials),
      );

      expect(error.title, 'Login Failed');
      expect(error.message, 'Invalid email or password.');
    });

    test('maps disabled accounts to support guidance', () {
      final error = ErrorHandler.handle(
        const ApiException(403, ApiFailureKind.accountDisabled),
      );

      expect(error.title, 'Account Disabled');
      expect(error.message, contains('contact support'));
    });

    test('maps invalid verification codes to resend guidance', () {
      final error = ErrorHandler.handle(
        const ApiException(400, ApiFailureKind.verificationCodeInvalid),
      );

      expect(error.title, 'Invalid Verification Code');
      expect(error.message, contains('Request a new code'));
      expect(error.canRetry, isFalse);
    });

    test('maps registration conflicts to a safe sign-in message', () {
      final error = ErrorHandler.handle(
        const ApiException(409, ApiFailureKind.conflict),
      );

      expect(error.title, 'Account Already Exists');
      expect(
        error.message,
        'This email is already registered. Try signing in.',
      );
      expect(error.canRetry, isFalse);
    });

    test('maps timeouts to a concise retry message', () {
      final error = ErrorHandler.handle(TimeoutException('internal timeout'));

      expect(error.title, 'Request Timed Out');
      expect(error.message, 'Request timed out. Please try again.');
    });

    test('shows a safe incorrect-current-password message', () {
      final error = ErrorHandler.handle(
        const ApiException(
          422,
          ApiFailureKind.validation,
          safeMessage: 'Current password is incorrect.',
        ),
      );

      expect(error.title, 'Check Your Details');
      expect(error.message, 'Current password is incorrect.');
    });
  });
}
