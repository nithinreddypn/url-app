import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/pages/app/profile/monthly_chart.dart';
import 'package:url_defender/models/url_scan_model.dart';
import 'package:url_defender/models/user_model.dart';
import 'package:url_defender/services/auth_service.dart';
import 'package:url_defender/providers/app_providers.dart';

class MockAuthService extends AuthService {
  final UserModel user;
  MockAuthService(this.user);

  @override
  Future<UserModel> currentUser() async => user;

  @override
  Future<bool> hasStoredSession() async => true;

  @override
  Future<void> signOut() async {}
}

class MockUserNotifier extends UserNotifier {
  MockUserNotifier(super.authService, UserModel? initialUser) {
    state = initialUser;
  }

  @override
  void _init() {}

  @override
  Future<void> refreshUser() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = UserModel(
    userId: 'test-user-123',
    email: 'tester@example.com',
    username: 'tester',
    role: 'user',
    createdAt: DateTime.now(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_session_token': 'debug-test-token',
    });
  });

  testWidgets('MonthlyActivityChart renders without crashing and shows empty state / chart', (tester) async {
    // Test case 1: Empty scans (all zero) -> Should render empty state
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWith((ref) {
            return MockUserNotifier(MockAuthService(testUser), testUser);
          }),
          recentScansProvider.overrideWith((ref) => []),
          scanHistoryProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MonthlyActivityChart(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Monthly activity'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);

    // Unmount to reset ProviderScope container
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // Test case 2: Real scans data -> Should render bar chart
    final scan1 = UrlScanModel(
      scanId: 'scan-1',
      userId: 'test-user-123',
      scannedUrl: 'google.com',
      scanResult: 'safe',
      scannedAt: DateTime.now().subtract(const Duration(days: 5)),
    );
    final scan2 = UrlScanModel(
      scanId: 'scan-2',
      userId: 'test-user-123',
      scannedUrl: 'malicious.ru',
      scanResult: 'dangerous',
      scannedAt: DateTime.now().subtract(const Duration(days: 35)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWith((ref) {
            return MockUserNotifier(MockAuthService(testUser), testUser);
          }),
          recentScansProvider.overrideWith((ref) => [scan1, scan2]),
          scanHistoryProvider.overrideWith((ref) => [scan1, scan2]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MonthlyActivityChart(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final element = tester.element(find.byType(MonthlyActivityChart));
    final container = ProviderScope.containerOf(element);
    final history = container.read(scanHistoryProvider);
    print('DEBUG scanHistoryProvider value: ${history.value}');

    expect(find.text('Monthly activity'), findsOneWidget);
    expect(find.text('No scans yet'), findsNothing);
  });
}
