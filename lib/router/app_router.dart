import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../pages/app/scan/scan_page.dart';
import '../views/auth/auth_gate.dart';
import '../views/auth/login_screen.dart';
import '../views/auth/signup_screen.dart';
import '../views/auth/verify_email_screen.dart';
import '../views/main_screen.dart';

import '../views/blocked_urls_screen.dart';
import '../views/auth/reset_password_screen.dart';
import '../views/scan_detail_screen.dart';
import '../pages/app/profile_page.dart';
import '../views/admin_community_reports_page.dart';
import '../views/community_reports_page.dart';
import '../views/community_report_detail_page.dart';
import '../views/report_flow/report_flow_wizard.dart';
import '../views/report_flow/my_report_status_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/auth_gate',
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context);
    final user = container.read(userProvider);

    // Check if the current URL/hash contains password recovery indicators
    final urlString = state.uri.toString().toLowerCase();
    final isRecoveryUrl =
        urlString.contains('recovery') ||
        urlString.contains('type=recovery') ||
        state.uri.queryParameters.containsKey('token');

    if (isRecoveryUrl &&
        state.matchedLocation != '/reset-password' &&
        state.matchedLocation != '/reset_password') {
      return Uri(
        path: '/reset-password',
        queryParameters: state.uri.queryParameters,
      ).toString();
    }

    if (user != null) {
      // User profile exists -> Dashboard
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/auth_gate';
      if (isLoggingIn) {
        return '/dashboard';
      }
      return null;
    } else {
      // No active user profile
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/auth_gate' ||
          state.matchedLocation == '/verify-email' ||
          state.matchedLocation == '/reset-password' ||
          state.matchedLocation == '/reset_password' ||
          state.matchedLocation == '/scan';
      return isLoggingIn ? null : '/auth_gate';
    }
  },
  routes: [
    GoRoute(path: '/auth_gate', builder: (context, state) => const AuthGate()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) =>
          VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),

    GoRoute(
      path: '/reset_password',
      builder: (context, state) =>
          ResetPasswordScreen(resetToken: state.uri.queryParameters['token']),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) =>
          ResetPasswordScreen(resetToken: state.uri.queryParameters['token']),
    ),
    GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(path: '/scan', builder: (context, state) => const ScanPage()),

    GoRoute(
      path: '/blocked_list',
      builder: (context, state) => const BlockedUrlsScreen(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/scan-detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ScanDetailScreen(scanId: id);
      },
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (context, state) => const AdminCommunityReportsPage(),
    ),
    GoRoute(
      path: '/community-reports',
      builder: (context, state) => const CommunityReportsPage(),
    ),
    GoRoute(
      path: '/community-reports/new',
      builder: (context, state) => const ReportFlowWizard(),
    ),
    GoRoute(
      path: '/community-reports/status/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return MyReportStatusScreen(reportId: id);
      },
    ),
    GoRoute(
      path: '/community-reports/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return CommunityReportDetailPage(reportId: id);
      },
    ),
  ],
);
