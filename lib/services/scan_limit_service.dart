import 'url_scan_service.dart';

class ScanLimitService {
  /// Count how many scans the user has performed this week (mocked as 0 for local simple usage).
  Future<int> getWeeklyScansCount(String userId) async {
    return 0;
  }

  /// Determine if the user is allowed to perform a URL scan.
  /// Allowed if user has completed < 50 lifetime scans.
  Future<bool> canUserScan(String userId) async {
    final scanCount = UrlScanService.getLocalScansCount(userId);
    return scanCount < 50;
  }

  /// Calculates the remaining scans for a free user based on the 50 limit.
  Future<int> getRemainingScans(String userId) async {
    final scanCount = UrlScanService.getLocalScansCount(userId);
    final remaining = 50 - scanCount;
    return remaining.clamp(0, 50);
  }
}
