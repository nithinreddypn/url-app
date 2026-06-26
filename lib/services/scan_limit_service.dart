import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';
import 'supabase_config.dart';

class ScanLimitService {
  final UserService _userService;
  final SupabaseClient? _supabaseClient;

  ScanLimitService({
    UserService? userService,
    SupabaseClient? supabaseClient,
  })  : _userService = userService ?? UserService(),
        // ignore: prefer_initializing_formals
        _supabaseClient = supabaseClient;

  SupabaseClient get _client => _supabaseClient ?? SupabaseConfig.client;

  /// Get the start of the current week (Monday 00:00:00 UTC).
  DateTime getWeekStart() {
    final now = DateTime.now().toUtc();
    // Monday = 1, Sunday = 7
    final daysSinceMonday = now.weekday - 1;
    final weekStart = DateTime.utc(now.year, now.month, now.day - daysSinceMonday);
    return weekStart;
  }

  /// Count how many scans the user has performed this week.
  Future<int> getWeeklyScansCount(String userId) async {
    try {
      final weekStart = getWeekStart();
      final response = await _client
          .from('url_scans')
          .select('scan_id')
          .eq('user_id', userId)
          .gte('scanned_at', weekStart.toIso8601String());

      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Determine if the user is allowed to perform a URL scan.
  /// Allowed if:
  /// - User is premium
  /// - Or user has completed < 15 lifetime scans (15 initial free scans)
  /// - Or user has completed >= 15 lifetime scans but has scans remaining this week (1 weekly scan).
  Future<bool> canUserScan(String userId) async {
    final userModel = await _userService.getUser(userId);
    if (userModel == null) return false;

    if (userModel.isPremium) return true;

    // Phase 1: 15 initial free scans
    if (userModel.lifetimeScanCount < 15) {
      return true;
    }

    // Phase 2: 1 free scan per week
    final weeklyLimit = 1;
    final weeklyScans = await getWeeklyScansCount(userId);
    return weeklyScans < weeklyLimit;
  }

  /// Calculates the remaining scans for a free user.
  /// If lifetime scans < 15, returns remaining out of the 15 initial free scans.
  /// If lifetime scans >= 15, returns remaining weekly scans (clamped to 0 or 1).
  /// For premium users, returns -1 (indicating unlimited).
  Future<int> getRemainingScans(String userId) async {
    final userModel = await _userService.getUser(userId);
    if (userModel == null) return 0;

    if (userModel.isPremium) return -1;

    // Phase 1: 15 initial free scans
    if (userModel.lifetimeScanCount < 15) {
      final remainingInitial = 15 - userModel.lifetimeScanCount;
      return remainingInitial.clamp(0, 15);
    }

    // Phase 2: 1 free scan per week
    final weeklyLimit = 1;
    final weeklyScans = await getWeeklyScansCount(userId);
    final remainingWeekly = weeklyLimit - weeklyScans;
    return remainingWeekly.clamp(0, weeklyLimit);
  }
}
