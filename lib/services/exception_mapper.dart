import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';


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

    final excStr = exception.toString();
    if (excStr.contains('AuthException') || excStr.contains('AuthApiException')) {
      final msg = excStr.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return MappedException(
          title: 'Unable to Sign In',
          description: 'Incorrect email or password.',
        );
      }
      if (msg.contains('already registered') || msg.contains('already exists')) {
        return MappedException(
          title: 'Account Already Exists',
          description: 'This email is already registered. Try logging in.',
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
          description: 'Please choose a stronger password.',
        );
      }
      if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
        return MappedException(
          title: 'Too Many Requests',
          description: 'Too many attempts. Please wait and try again later.',
        );
      }
      return MappedException(
        title: 'Authentication Error',
        description: _cleanErrorMessage(excStr),
      );
    }

    if (excStr.contains('PostgrestException')) {
      final msg = excStr.toLowerCase();
      if (msg.contains('timeout') || msg.contains('deadlock')) {
        return MappedException(
          title: 'Service Temporarily Unavailable',
          description: 'Connection problem. Check your internet and try again.',
        );
      }
      if (msg.contains('violates row-level security') || msg.contains('rls') || msg.contains('42501')) {
        return MappedException(
          title: 'Access Restricted',
          description: 'Connection problem. Check your internet and try again.',
        );
      }
      return MappedException(
        title: 'Database Action Failed',
        description: 'Connection problem. Check your internet and try again.',
      );
    }

    if (exception is SocketException || exception is HttpException) {
      return MappedException(
        title: 'Connection Problem',
        description: 'Connection problem. Check your internet and try again.',
      );
    }

    if (exception is TimeoutException) {
      return MappedException(
        title: 'Service Temporarily Unavailable',
        description: 'Connection problem. Check your internet and try again.',
      );
    }

    if (exception is FormatException) {
      return MappedException(
        title: 'Data Processing Error',
        description: 'Something went wrong. Please try again.',
      );
    }

    if (exception is PlatformException) {
      return MappedException(
        title: 'System Error',
        description: 'Something went wrong. Please try again.',
      );
    }

    // Fallback checks on generic string representation
    final String errorString = exception.toString().toLowerCase();
    if (errorString.contains('network') || errorString.contains('socket')) {
      return MappedException(
        title: 'Connection Problem',
        description: 'Connection problem. Check your internet and try again.',
      );
    }
    if (errorString.contains('timeout')) {
      return MappedException(
        title: 'Service Temporarily Unavailable',
        description: 'Connection problem. Check your internet and try again.',
      );
    }
    if (errorString.contains('rate limit') || errorString.contains('over_email_send_rate_limit')) {
      return MappedException(
        title: 'Too Many Requests',
        description: 'Too many attempts. Please wait and try again later.',
      );
    }

    return MappedException(
      title: 'Action Failed',
      description: _cleanErrorMessage(exception.toString()),
    );
  }

  /// Extracts the user-friendly part of a raw developer/library error message.
  static String _cleanErrorMessage(String rawMessage) {
    // If the message is a JSON string (e.g. from backend SMTP failure), parse it:
    if (rawMessage.trim().startsWith('{')) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(rawMessage);
        if (parsed.containsKey('message')) {
          return _cleanErrorMessage(parsed['message'].toString());
        }
      } catch (_) {}
    }

    final lower = rawMessage.toLowerCase();
    if (lower.contains('email rate limit exceeded') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait and try again later.';
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('user not found') || lower.contains('user_not_found')) {
      return 'No user account found with this email.';
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'This email is already registered. Try logging in.';
    }
    if (lower.contains('error sending confirmation email') || lower.contains('confirmation email')) {
      return 'Verification email failed to send. Please check your SMTP settings or use a whitelisted testing email.';
    }
    if (lower.contains('error sending recovery email') || lower.contains('recovery email')) {
      return 'Recovery email failed to send. Please check your SMTP settings or use a whitelisted testing email.';
    }

    // Parse out raw message value if it matches Supabase exception format:
    // e.g. "AuthApiException(message: email rate limit exceeded, statusCode: 429, ...)"
    if (rawMessage.contains('message:')) {
      final regExp = RegExp(r'message:\s*([^,)]+)');
      final match = regExp.firstMatch(rawMessage);
      if (match != null && match.group(1) != null) {
        final cleaned = match.group(1)!.trim();
        return _cleanErrorMessage(cleaned);
      }
    }

    // Fallback: If it's a generic unhandled exception, show a simple friendly instruction instead of stack/code
    if (rawMessage.contains('Exception:') || rawMessage.contains('AuthApiException') || rawMessage.contains('PostgrestException')) {
      return 'Something went wrong. Please try again.';
    }

    return rawMessage;
  }
}
