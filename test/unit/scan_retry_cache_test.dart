import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/views/scan_screen.dart';
import 'package:url_defender/models/url_scan_model.dart';
import 'package:url_defender/models/url_lookup_result.dart';
import 'package:url_defender/models/user_model.dart';
import 'package:url_defender/services/url_scan_service.dart';
import 'package:url_defender/services/scan_limit_service.dart';
import 'package:url_defender/services/auth_service.dart';
import 'package:url_defender/providers/app_providers.dart';

class MockUrlScanService extends UrlScanService {
  int scanCalls = 0;
  String? lastUrl;

  @override
  Future<UrlLookupResult> lookupUrl({required String userId, required String url}) async {
    return const UrlLookupResult(exists: false);
  }

  @override
  Future<UrlScanModel> scanUrlWithVirusTotal({required String scannedUrl, required String userId}) async {
    scanCalls++;
    lastUrl = scannedUrl;
    return UrlScanModel(
      scanId: 'test-scan-id',
      userId: userId,
      scannedUrl: scannedUrl,
      scanResult: 'safe',
      scannedAt: DateTime.now(),
    );
  }
}

class MockScanLimitService implements ScanLimitService {
  @override
  Future<bool> canUserScan(String userId) async => true;

  @override
  Future<int> getWeeklyScansCount(String userId) async => 0;

  @override
  Future<int> getRemainingScans(String userId) async => 50;
}

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

class TestWrapper extends StatefulWidget {
  const TestWrapper({super.key});

  @override
  State<TestWrapper> createState() => TestWrapperState();
}

class TestWrapperState extends State<TestWrapper> {
  bool showScanScreen = true;

  @override
  Widget build(BuildContext context) {
    if (showScanScreen) {
      return const ScanScreen();
    }
    return const SizedBox.shrink();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ScanScreen _performScan cache hit for safe URLs, bypass for pending/error', (tester) async {
    // Set up mock SharedPreferences to prevent initialization exceptions in AuthService/ApiClient
    SharedPreferences.setMockInitialValues({
      'api_session_token': 'debug-test-token',
    });

    final mockService = MockUrlScanService();
    final mockLimitService = MockScanLimitService();

    final testUser = UserModel(
      userId: 'test-user-123',
      email: 'tester@example.com',
      username: 'tester',
      role: 'user',
      createdAt: DateTime.now(),
    );

    final safeScan = UrlScanModel(
      scanId: 'scan-safe',
      userId: 'test-user-123',
      scannedUrl: 'youtube.com',
      scanResult: 'safe',
      scannedAt: DateTime.now(),
    );

    final pendingScan = UrlScanModel(
      scanId: 'scan-pending',
      userId: 'test-user-123',
      scannedUrl: 'instagram.com',
      scanResult: 'pending',
      scannedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWith((ref) {
            return MockUserNotifier(MockAuthService(testUser), testUser);
          }),
          urlScanServiceProvider.overrideWithValue(mockService),
          scanLimitServiceProvider.overrideWithValue(mockLimitService),
          recentScansProvider.overrideWith((ref) => [safeScan, pendingScan]),
        ],
        child: MaterialApp(
          home: const TestWrapper(),
        ),
      ),
    );

    // Let initialization complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify providers state using the container
    final element = tester.element(find.byType(ScanScreen));
    final container = ProviderScope.containerOf(element);

    final user = container.read(userProvider);
    expect(user, isNotNull, reason: 'userProvider must not be null');
    expect(user!.userId, 'test-user-123');

    final recentScans = container.read(recentScansProvider);
    expect(recentScans.hasValue, isTrue, reason: 'recentScansProvider should be loaded');
    expect(recentScans.value!.length, 2);

    // Verify scan input is present
    final textInputFinder = find.byType(TextField);
    expect(textInputFinder, findsOneWidget);

    final scanButtonFinder = find.byKey(const ValueKey('scan_button'));
    expect(scanButtonFinder, findsOneWidget);

    // Test Case 1: Enter youtube.com (cached as Safe) -> Should HIT cache (0 scan calls)
    await tester.enterText(textInputFinder, 'youtube.com');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(scanButtonFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify cache was hit: scanCalls is still 0
    expect(mockService.scanCalls, 0);

    // Test Case 2: Enter instagram.com (cached as Pending) -> Should BYPASS cache (1 scan call)
    await tester.enterText(textInputFinder, 'instagram.com');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(scanButtonFinder);
    await tester.pump(const Duration(milliseconds: 200)); // Start scan trigger
    await tester.pump(const Duration(seconds: 1)); // Wait for async task inside scan trigger to execute

    // Verify cache was bypassed: scanCalls is now 1
    expect(mockService.scanCalls, 1);
    expect(mockService.lastUrl, 'instagram.com');

    // Remove ScanScreen from the widget tree while the ProviderScope (Riverpod context) is still active.
    // This allows ScanScreen.dispose() to run and safely access the active Riverpod ref to cancel timers
    // without invoking defunct/disposed ref assertions.
    final wrapperState = tester.state<TestWrapperState>(find.byType(TestWrapper));
    wrapperState.setState(() {
      wrapperState.showScanScreen = false;
    });
    await tester.pump();

    // Now safely tear down the entire widget tree (including the ProviderScope)
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
