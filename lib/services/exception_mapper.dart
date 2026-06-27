import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MappedException {
  final String title;
  final String description;

  MappedException({required this.title, required this.description});
}

class ExceptionMapper {
  /// Maps complex errors/exceptions into user-friendly titles and descriptions.
  static MappedException map(dynamic exception) {
    // Log exception in debug/development mode only
    assert(() {
      // ignore: avoid_print
      print('Centralized Exception Logger caught: $exception');
      if (exception is Error && exception.stackTrace != null) {
        // ignore: avoid_print
        print(exception.stackTrace);
      }
      return true;
    }());

    if (exception is AuthException) {
      final msg = exception.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return MappedException(
          title: 'Unable to Sign In',
          description: 'Incorrect email or password.',
        );
      }
      if (msg.contains('already registered') || msg.contains('already exists')) {
        return MappedException(
          title: 'Account Already Exists',
          description: 'An account with this email already exists.',
        );
      }
      if (msg.contains('email not confirmed') || msg.contains('confirm your email') || msg.contains('email_not_confirmed')) {
        return MappedException(
          title: 'Email Verification Required',
          description: 'Please verify your email before signing in.',
        );
      }
      if (msg.contains('expired') || msg.contains('verification link has expired')) {
        return MappedException(
          title: 'Verification Expired',
          description: 'Your verification link has expired. Please request a new verification email.',
        );
      }
      if (msg.contains('weak password') || msg.contains('password should be')) {
        return MappedException(
          title: 'Password Too Weak',
          description: 'Please choose a stronger password that meets all security requirements.',
        );
      }
      return MappedException(
        title: 'Authentication Error',
        description: exception.message,
      );
    }

    if (exception is PostgrestException) {
      final msg = exception.message.toLowerCase();
      if (msg.contains('timeout') || msg.contains('deadlock')) {
        return MappedException(
          title: 'Service Temporarily Unavailable',
          description: 'Please check your internet connection.',
        );
      }
      return MappedException(
        title: 'Database Action Failed',
        description: 'Please check your internet connection.',
      );
    }

    if (exception is SocketException || exception is HttpException) {
      return MappedException(
        title: 'Connection Problem',
        description: 'Please check your internet connection.',
      );
    }

    if (exception is TimeoutException) {
      return MappedException(
        title: 'Service Temporarily Unavailable',
        description: 'Please check your internet connection.',
      );
    }

    if (exception is FormatException) {
      return MappedException(
        title: 'Data Processing Error',
        description: 'The service returned an unexpected response format. Please try again.',
      );
    }

    if (exception is PlatformException) {
      return MappedException(
        title: 'System Error',
        description: exception.message ?? 'A system operation failed. Please try again.',
      );
    }

    // Fallback checks on generic string representation
    final String errorString = exception.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('socket')) {
      return MappedException(
        title: 'Connection Problem',
        description: 'Please check your internet connection.',
      );
    }
    if (errorString.contains('timeout')) {
      return MappedException(
        title: 'Service Temporarily Unavailable',
        description: 'Please check your internet connection.',
      );
    }

    return MappedException(
      title: 'Action Failed',
      description: 'An unexpected error occurred. Please try again.',
    );
  }
}
