import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../views/auth/auth_gate.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/main_screen.dart';
import '../views/premium_screen.dart';
import '../views/scan_history_screen.dart';
import '../views/blocked_urls_screen.dart';
import '../views/auth/reset_password_screen.dart';

bool isPasswordRecoveryMode = false;

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (AuthState state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          isPasswordRecoveryMode = true;
        } else if (state.event == AuthChangeEvent.signedOut || state.event == AuthChangeEvent.signedIn) {
          isPasswordRecoveryMode = false;
        }
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/auth_gate',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    
    // Redirect user to password recovery if deep link flag is set
    if (isPasswordRecoveryMode) {
      if (state.matchedLocation == '/reset-password' || state.matchedLocation == '/reset_password') return null;
      return '/reset-password';
    }

    if (session != null) {
      // Email is verified (or bypassed) and session exists -> Dashboard
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/auth_gate';
      if (isLoggingIn) {
        return '/dashboard';
      }
      return null;
    } else {
      // No active session
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
      path: '/premium',
      builder: (context, state) => PremiumScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => ScanHistoryScreen(),
    ),
    GoRoute(
      path: '/blocked_list',
      builder: (context, state) => const BlockedUrlsScreen(),
    ),
  ],
);
