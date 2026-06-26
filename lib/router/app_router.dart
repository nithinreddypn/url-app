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

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (AuthState state) => notifyListeners(),
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
    final isLoggingIn = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/auth_gate';

    if (session == null) {
      // User is not logged in. Redirect to auth_gate if they try to access any other page.
      return isLoggingIn ? null : '/auth_gate';
    }

    // User is logged in. Redirect to main if they try to go to login pages.
    if (isLoggingIn) {
      return '/main';
    }

    return null; // Keep going to requested page
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
      path: '/main',
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
