import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../views/auth/auth_gate.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/main_screen.dart';

import '../views/scan_history_screen.dart';
import '../views/blocked_urls_screen.dart';
import '../views/auth/reset_password_screen.dart';
import '../views/scan_detail_screen.dart';
bool isPasswordRecoveryMode = false;

final appRouter = GoRouter(
  initialLocation: '/auth_gate',
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context);
    final user = container.read(userProvider);
    
    // Check if the current URL/hash contains password recovery indicators
    final urlString = state.uri.toString().toLowerCase();
    final isRecoveryUrl = urlString.contains('recovery') || urlString.contains('type=recovery');
    
    if (isRecoveryUrl) {
      isPasswordRecoveryMode = true;
    }

    // Redirect user to password recovery if deep link flag is set
    if (isPasswordRecoveryMode) {
      if (state.matchedLocation == '/reset-password' || state.matchedLocation == '/reset_password') return null;
      return '/reset-password';
    }

    if (user != null) {
      // User profile exists -> Dashboard
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/auth_gate';
      if (isLoggingIn) {
        return '/dashboard';
      }
      return null;
    } else {
      // No active user profile
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/auth_gate';
      return isLoggingIn ? null : '/auth_gate';
    }
  },
  routes: [
    GoRoute(
      path: '/auth_gate',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),

    GoRoute(
      path: '/reset_password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const MainScreen(),
    ),

    GoRoute(
      path: '/history',
      builder: (context, state) => ScanHistoryScreen(),
    ),
    GoRoute(
      path: '/blocked_list',
      builder: (context, state) => const BlockedUrlsScreen(),
    ),
    GoRoute(
      path: '/scan-detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ScanDetailScreen(scanId: id);
      },
    ),
  ],
);
