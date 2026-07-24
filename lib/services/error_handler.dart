import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class AppError {
  final String title;
  final String message;
  final bool canRetry;

  const AppError({
    required this.title,
    required this.message,
    this.canRetry = true,
  });
}

/// Converts implementation errors into safe text suitable for production UI.
class ErrorHandler {
  const ErrorHandler._();

  static AppError handle(Object error, [StackTrace? stackTrace]) {
    _debugLog(error, stackTrace);

    if (error is ApiException) {
      return _fromApi(error);
    }
    if (error is TimeoutException) {
      return const AppError(
        title: 'Request Timed Out',
        message: 'Request timed out. Please try again.',
      );
    }
    if (error is SocketException || error is http.ClientException) {
      return const AppError(
        title: 'Unable to Connect',
        message:
            'Unable to reach the service. Check your connection and try again.',
      );
    }
    if (error is HttpException) {
      return const AppError(
        title: 'Service Unavailable',
        message: 'Service is temporarily unavailable. Please try again later.',
      );
    }
    if (error is FormatException ||
        error is PlatformException ||
        error is StateError ||
        error is TypeError) {
      return const AppError(
        title: 'Something Went Wrong',
        message: 'Something went wrong. Please try again.',
      );
    }
    return const AppError(
      title: 'Something Went Wrong',
      message: 'Something went wrong. Please try again.',
    );
  }

  static AppError _fromApi(ApiException error) {
    switch (error.kind) {
      case ApiFailureKind.connection:
        return const AppError(
          title: 'Unable to Connect',
          message:
              'Unable to reach the service. Check your connection and try again.',
        );
      case ApiFailureKind.timeout:
        return const AppError(
          title: 'Request Timed Out',
          message: 'Request timed out. Please try again.',
        );
      case ApiFailureKind.invalidCredentials:
        return const AppError(
          title: 'Login Failed',
          message: 'Invalid email or password.',
          canRetry: false,
        );
      case ApiFailureKind.accountNotFound:
        return const AppError(
          title: 'Account Not Found',
          message: 'No account found with this email.',
          canRetry: false,
        );
      case ApiFailureKind.accountDisabled:
        return const AppError(
          title: 'Account Disabled',
          message: 'Your account has been disabled. Please contact support.',
          canRetry: false,
        );
      case ApiFailureKind.emailVerificationRequired:
        return const AppError(
          title: 'Verification Required',
          message: 'Please verify your email before signing in.',
          canRetry: false,
        );
      case ApiFailureKind.verificationCodeInvalid:
        return const AppError(
          title: 'Invalid Verification Code',
          message:
              'The code is invalid or has expired. Request a new code and try again.',
          canRetry: false,
        );
      case ApiFailureKind.conflict:
        return const AppError(
          title: 'Account Already Exists',
          message: 'This email is already registered. Try signing in.',
          canRetry: false,
        );
      case ApiFailureKind.rateLimited:
        return const AppError(
          title: 'Please Wait',
          message: 'Too many attempts. Please wait a moment and try again.',
        );
      case ApiFailureKind.validation:
        return AppError(
          title: 'Check Your Details',
          message:
              error.safeMessage ??
              'Please check the information you entered and try again.',
          canRetry: false,
        );
      case ApiFailureKind.unauthorized:
        return const AppError(
          title: 'Sign In Required',
          message: 'Please sign in again to continue.',
          canRetry: false,
        );
      case ApiFailureKind.serverUnavailable:
        return const AppError(
          title: 'Service Unavailable',
          message:
              'Service is temporarily unavailable. Please try again later.',
        );
      case ApiFailureKind.notFound:
        return const AppError(
          title: 'Not Found',
          message: 'The requested information could not be found.',
          canRetry: false,
        );
      case ApiFailureKind.invalidResponse:
      case ApiFailureKind.unknown:
        return const AppError(
          title: 'Something Went Wrong',
          message: 'Something went wrong. Please try again.',
        );
    }
  }

  static void _debugLog(Object error, StackTrace? stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[ErrorHandler] $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }
}
