import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_defender/services/scan_limit_service.dart';
import 'package:url_defender/services/url_scan_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('ScanLimitService Tests (50 Free Limits)', () {
    late ScanLimitService scanLimitService;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'api_session_token': 'debug-test-session-scan-limit',
      });
      scanLimitService = ScanLimitService();
    });

    test('Free user with 5 lifetime scans gets remaining 45 scans', () async {
      final userId = 'test_user_1';
      final scanService = UrlScanService();
      await scanService.deleteScan('all', userId: userId);

      for (int i = 0; i < 5; i++) {
        await scanService.scanUrl(
          userId: userId,
          scannedUrl: 'http://test$i.com',
        );
      }

      final canScan = await scanLimitService.canUserScan(userId);
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans(userId);
      expect(remaining, 45); // 50 - 5
    });

    test('Free user with 49 lifetime scans has 1 remaining scan', () async {
      final userId = 'test_user_2';
      final scanService = UrlScanService();
      await scanService.deleteScan('all', userId: userId);

      for (int i = 0; i < 49; i++) {
        await scanService.scanUrl(
          userId: userId,
          scannedUrl: 'http://test$i.com',
        );
      }

      final canScan = await scanLimitService.canUserScan(userId);
      expect(canScan, true);

      final remaining = await scanLimitService.getRemainingScans(userId);
      expect(remaining, 1); // 50 - 49
    });

    test('Free user with 50 lifetime scans is blocked', () async {
      final userId = 'test_user_3';
      final scanService = UrlScanService();
      await scanService.deleteScan('all', userId: userId);

      for (int i = 0; i < 50; i++) {
        await scanService.scanUrl(
          userId: userId,
          scannedUrl: 'http://test$i.com',
        );
      }

      final canScan = await scanLimitService.canUserScan(userId);
      expect(canScan, false);

      final remaining = await scanLimitService.getRemainingScans(userId);
      expect(remaining, 0); // 50 - 50
    });
  });
}
