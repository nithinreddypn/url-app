import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/services/auth_service.dart';
import 'package:url_defender/services/scan_limit_service.dart';
import 'package:url_defender/services/url_scan_service.dart';

const _enabled = bool.fromEnvironment('ENABLE_TEST_LOGIN');
const _email = String.fromEnvironment('TEST_LOGIN_EMAIL');
const _password = String.fromEnvironment('TEST_LOGIN_PASSWORD');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'debug test login persists and signs out locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = AuthService();

      final session = await service.signIn(email: _email, password: _password);
      expect(session.user.email, _email.toLowerCase());
      expect((await service.currentUser()).userId, 'debug-test-user');

      final scanService = UrlScanService();
      final scan = await scanService.scanUrlWithVirusTotal(
        scannedUrl: 'https://example.com',
        userId: session.user.userId,
      );
      expect(scan.scanResult, 'safe');
      expect(
        await ScanLimitService().getRemainingScans(session.user.userId),
        49,
      );

      await service.signOut();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('debug_test_session_active'), isNull);
    },
    skip: !kDebugMode || !_enabled || _email.isEmpty || _password.isEmpty,
  );
}
