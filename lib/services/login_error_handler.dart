import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

enum LoginErrorAction {
  retry,
  reviewCredentials,
  createAccount,
  verifyEmail,
  dismiss,
}

class LoginUiError {
  final String title;
  final String description;
  final String actionLabel;
  final LoginErrorAction action;

  const LoginUiError({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.action,
  });
}

/// The only conversion point from login failures to user-visible content.
/// Raw exception messages and response bodies are never copied into the UI.
class LoginErrorHandler {
  const LoginErrorHandler._();

  static LoginUiError fromException(Object error, [StackTrace? stackTrace]) {
    _debugLog(error, stackTrace);
    if (error is ApiException) return _fromApiFailure(error.kind);
    if (error is TimeoutException) return _timeout;
    if (error is SocketException || error is http.ClientException) {
      return _connection;
    }
    if (error is HttpException) return _serviceUnavailable;
    if (error is FormatException ||
        error is PlatformException ||
        error is StateError ||
        error is TypeError) {
      return _unexpected;
    }
    return _unexpected;
  }

  /// Maps every Google authentication failure to one safe response.
  ///
  /// Google SDK errors and token-exchange failures must not be interpreted as
  /// email/password failures or copied into user-visible text.
  static LoginUiError fromGoogleException(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    _debugLog(error, stackTrace);
    if (error is ApiException) {
      if (error.statusCode == 403 && error.safeMessage != null) {
        return LoginUiError(
          title: 'Verification Required',
          description: error.safeMessage!,
          actionLabel: 'OK',
          action: LoginErrorAction.dismiss,
        );
      }
    }
    return LoginUiError(
      title: 'Google Sign-In Unavailable',
      description: 'Unable to complete Google Sign-In. Error details: $error',
      actionLabel: 'Use Email',
      action: LoginErrorAction.dismiss,
    );
  }

  /// Maps an HTTP status without reading or exposing its raw response body.
  static LoginUiError fromHttpStatus(int statusCode) {
    if (statusCode == 401) return _invalidCredentials;
    if (statusCode == 403) return _accessDenied;
    if (statusCode == 404) return _accountNotFound;
    if (statusCode == 408 || statusCode == 504) return _timeout;
    if (statusCode == 429) return _rateLimited;
    if (statusCode >= 500) return _serviceUnavailable;
    return _unexpected;
  }

  static LoginUiError _fromApiFailure(ApiFailureKind kind) {
    return switch (kind) {
      ApiFailureKind.connection => _connection,
      ApiFailureKind.timeout => _timeout,
      ApiFailureKind.invalidCredentials => _invalidCredentials,
      ApiFailureKind.accountNotFound => _accountNotFound,
      ApiFailureKind.accountDisabled => _accountDisabled,
      ApiFailureKind.emailVerificationRequired => _verificationRequired,
      ApiFailureKind.verificationCodeInvalid => _invalidInput,
      ApiFailureKind.rateLimited => _rateLimited,
      ApiFailureKind.validation => _invalidInput,
      ApiFailureKind.serverUnavailable => _serviceUnavailable,
      ApiFailureKind.unauthorized => _accessDenied,
      ApiFailureKind.conflict ||
      ApiFailureKind.notFound ||
      ApiFailureKind.invalidResponse ||
      ApiFailureKind.unknown => _unexpected,
    };
  }

  static const _connection = LoginUiError(
    title: 'Unable to Sign In',
    description:
        'The sign-in service could not be reached. Check your connection and try again.',
    actionLabel: 'Try Again',
    action: LoginErrorAction.retry,
  );
  static const _timeout = LoginUiError(
    title: 'Request Timed Out',
    description: 'The sign-in request took too long. Please try again.',
    actionLabel: 'Try Again',
    action: LoginErrorAction.retry,
  );
  static const _invalidCredentials = LoginUiError(
    title: 'Login Failed',
    description: 'Invalid email or password.',
    actionLabel: 'Review Details',
    action: LoginErrorAction.reviewCredentials,
  );
  static const _accountNotFound = LoginUiError(
    title: 'Account Not Found',
    description: 'No account was found with this email.',
    actionLabel: 'Create Account',
    action: LoginErrorAction.createAccount,
  );
  static const _accountDisabled = LoginUiError(
    title: 'Account Disabled',
    description: 'This account is disabled. Please contact support.',
    actionLabel: 'Close',
    action: LoginErrorAction.dismiss,
  );
  static const _verificationRequired = LoginUiError(
    title: 'Verification Required',
    description: 'Please verify your email before signing in.',
    actionLabel: 'Verify Email',
    action: LoginErrorAction.verifyEmail,
  );
  static const _rateLimited = LoginUiError(
    title: 'Please Wait',
    description: 'Too many attempts were made. Please wait and try again.',
    actionLabel: 'Try Again',
    action: LoginErrorAction.retry,
  );
  static const _invalidInput = LoginUiError(
    title: 'Check Your Details',
    description: 'Please check your email and password, then try again.',
    actionLabel: 'Review Details',
    action: LoginErrorAction.reviewCredentials,
  );
  static const _accessDenied = LoginUiError(
    title: 'Unable to Sign In',
    description: 'We could not sign you in. Please check your details.',
    actionLabel: 'Review Details',
    action: LoginErrorAction.reviewCredentials,
  );
  static const _serviceUnavailable = LoginUiError(
    title: 'Service Unavailable',
    description: 'Sign-in is temporarily unavailable. Please try again later.',
    actionLabel: 'Retry',
    action: LoginErrorAction.retry,
  );
  static const _unexpected = LoginUiError(
    title: 'Unable to Sign In',
    description: 'We could not sign you in at the moment. Please try again.',
    actionLabel: 'Try Again',
    action: LoginErrorAction.retry,
  );
  static const _googleUnavailable = LoginUiError(
    title: 'Google Sign-In Unavailable',
    description:
        'Unable to complete Google Sign-In. Please try again later or use email and password.',
    actionLabel: 'Use Email',
    action: LoginErrorAction.dismiss,
  );

  static void _debugLog(Object error, StackTrace? stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[LoginErrorHandler] $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }
}
