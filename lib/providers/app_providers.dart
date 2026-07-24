import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';
import '../models/blocked_url_model.dart';
import '../models/url_scan_model.dart';
import '../services/url_scan_service.dart';
import '../services/auth_service.dart';
import '../services/plan_repository.dart';
import '../services/subscription_repository.dart';
import '../services/scan_limit_service.dart';
import '../services/blocked_url_service.dart';
import '../services/community_threat_service.dart';

// Service & Repository Providers
final authServiceProvider = Provider((ref) => AuthService());
final communityThreatServiceProvider = Provider((ref) => CommunityThreatService());
final planRepositoryProvider = Provider((ref) => PlanRepository());
final subscriptionRepositoryProvider = Provider(
  (ref) => SubscriptionRepository(),
);

final scanLimitServiceProvider = Provider((ref) {
  return ScanLimitService();
});

// State Providers

/// Exposes the current authenticated user's model and profiles metadata.
final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UserNotifier(authService);
});

class UserNotifier extends StateNotifier<UserModel?> {
  final AuthService _authService;
  bool _signedOut = false;
  int _operationRevision = 0;
  int _profileRevision = 0;

  UserNotifier(this._authService) : super(null) {
    _init();
  }

  void _init() async {
    final operation = ++_operationRevision;
    try {
      if (!await _authService.hasStoredSession()) return;
      final user = await _authService.currentUser();
      await _applyUser(user, operation);
    } catch (error, stackTrace) {
      await _clearPersistedUserIfCurrent(operation);
      await _authService.signOut(); // Clear the invalid session token!
      _debugLog('Initial profile refresh failed', error, stackTrace);
    }
  }

  Future<void> loginWithSession(AuthSession session) async {
    _signedOut = false;
    final operation = ++_operationRevision;
    await _applyUser(session.user, operation);
  }

  Future<void> logout() async {
    // Clear reactive/local profile state immediately so routing can no longer
    // treat the user as authenticated while the server logout is in flight.
    _signedOut = true;
    _operationRevision++;
    _profileRevision++;
    final previousAvatar = state?.avatarUrl;
    state = null;
    _invalidateAvatar(previousAvatar);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user');
    await _authService.signOut();
  }

  Future<void> refreshUser() async {
    if (state == null) return;
    final operation = ++_operationRevision;
    final user = await _authService.currentUser();
    await _applyUser(user, operation);
  }

  Future<void> updateProfile({required String fullName}) async {
    final operation = ++_operationRevision;
    final user = await _authService.updateProfile(fullName: fullName);
    await _applyUser(user, operation);
    await _refreshAfterMutation(operation);
  }

  Future<void> uploadAvatar(XFile image) async {
    final operation = ++_operationRevision;
    final user = await _authService.uploadAvatar(image);
    await _applyUser(user, operation);
    await _refreshAfterMutation(operation);
  }

  Future<void> removeAvatar() async {
    final operation = ++_operationRevision;
    final user = await _authService.removeAvatar();
    await _applyUser(user, operation);
    await _refreshAfterMutation(operation);
  }

  Future<void> upgradeUserToPremium() async {
    if (state == null) return;
    await refreshUser();
  }

  Future<void> deleteAccount() async {
    _signedOut = true;
    _operationRevision++;
    _profileRevision++;
    final previousAvatar = state?.avatarUrl;
    state = null;
    _invalidateAvatar(previousAvatar);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user');
    await _authService.deleteAccount();
  }

  bool _canApply(int operation) =>
      !_signedOut && operation == _operationRevision;

  Future<void> _applyUser(UserModel user, int operation) async {
    if (!_canApply(operation)) return;
    final previousAvatar = state?.avatarUrl;
    final profile = ++_profileRevision;
    state = user;

    if (previousAvatar != user.avatarUrl) {
      _invalidateAvatar(previousAvatar);
      _invalidateAvatar(user.avatarUrl);
    }
    await _persistUserIfCurrent(user, operation, profile);
  }

  /// Mutation responses update the UI immediately, then `/me` is fetched as
  /// the canonical source of truth. If reconciliation is temporarily
  /// unavailable, the successful mutation response remains visible.
  Future<void> _refreshAfterMutation(int operation) async {
    if (!_canApply(operation)) return;
    try {
      final canonicalUser = await _authService.currentUser();
      await _applyUser(canonicalUser, operation);
    } catch (error, stackTrace) {
      _debugLog('Profile reconciliation failed', error, stackTrace);
    }
  }

  Future<void> _persistUserIfCurrent(
    UserModel user,
    int operation,
    int profile,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_canApply(operation) || profile != _profileRevision) return;
      await prefs.setString('active_user', jsonEncode(user.toJson()));
    } catch (error, stackTrace) {
      _debugLog('Profile cache write failed', error, stackTrace);
    }
  }

  Future<void> _clearPersistedUserIfCurrent(int operation) async {
    if (!_canApply(operation)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_canApply(operation)) await prefs.remove('active_user');
    } catch (error, stackTrace) {
      _debugLog('Profile cache clear failed', error, stackTrace);
    }
  }

  void _invalidateAvatar(String? avatarUrl) {
    if (avatarUrl == null ||
        !(avatarUrl.startsWith('http://') ||
            avatarUrl.startsWith('https://'))) {
      return;
    }
    unawaited(
      NetworkImage(avatarUrl).evict().catchError((Object error) {
        if (kDebugMode) {
          debugPrint('[UserNotifier] Avatar cache eviction failed: $error');
        }
        return false;
      }),
    );
  }

  void _debugLog(String context, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[UserNotifier] $context: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

/// Exposes dynamic active pricing plans.
final planProvider = FutureProvider<List<PlanModel>>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  return await repo.getActivePlans();
});

/// Exposes the current active subscription, treating the subscriptions table as the source of truth.
final subscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;

  try {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return await repo.getActiveSubscription(user.userId);
  } catch (e) {
    if (kDebugMode) debugPrint('Subscription provider failed: $e');
    return null;
  }
});

/// Exposes remaining scan counts.
final scanLimitProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return 0;

  try {
    final scanLimitService = ref.watch(scanLimitServiceProvider);
    return await scanLimitService.getRemainingScans(user.userId);
  } catch (e) {
    if (kDebugMode) debugPrint('Scan limit provider failed: $e');
    return 0;
  }
});

final blockedUrlsProvider = FutureProvider<List<BlockedUrlModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  try {
    final blockedService = BlockedUrlService();
    return await blockedService.getBlockedUrls(user.userId);
  } catch (e) {
    if (kDebugMode) debugPrint('Blocked URL provider failed: $e');
    return [];
  }
});

// Payment State StateNotifier

enum PaymentStatus { idle, loading, success, failure }

class PaymentState {
  final PaymentStatus status;
  final String? errorMessage;

  PaymentState({required this.status, this.errorMessage});

  factory PaymentState.idle() => PaymentState(status: PaymentStatus.idle);
  factory PaymentState.loading() => PaymentState(status: PaymentStatus.loading);
  factory PaymentState.success() => PaymentState(status: PaymentStatus.success);
  factory PaymentState.failure(String message) =>
      PaymentState(status: PaymentStatus.failure, errorMessage: message);
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((
  ref,
) {
  final subRepo = ref.watch(subscriptionRepositoryProvider);
  final userNotif = ref.watch(userProvider.notifier);
  return PaymentNotifier(ref, subRepo, userNotif);
});

class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref _ref;
  final SubscriptionRepository _subRepo;
  final UserNotifier _userNotifier;

  PaymentNotifier(this._ref, this._subRepo, this._userNotifier)
    : super(PaymentState.idle());

  void setIdle() {
    state = PaymentState.idle();
  }

  void setLoading() {
    state = PaymentState.loading();
  }

  void setFailure(String message) {
    state = PaymentState.failure(message);
  }

  Future<PaymentOrder> createOrder(String planId, {String? couponCode}) =>
      _subRepo.createPaymentOrder(planId, couponCode: couponCode);

  Future<bool> verifyAndUpgrade({
    required String planId,
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
  }) async {
    state = PaymentState.loading();

    final user = _ref.read(userProvider);
    if (user == null) {
      state = PaymentState.failure('No active user session found.');
      return false;
    }

    final success = await _subRepo.verifyPaymentAndUpgrade(
      userId: user.userId,
      planId: planId,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      amount: amount,
    );

    if (success) {
      state = PaymentState.success();
      // Upgrade user premium status in persistent storage and session cache
      await _userNotifier.upgradeUserToPremium();
      _ref.invalidate(subscriptionProvider);
      _ref.invalidate(scanLimitProvider);
      return true;
    } else {
      state = PaymentState.failure(
        'Payment verification signature check failed.',
      );
      return false;
    }
  }
}

// Theme State Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

// --- Resend Verification Email Cooldown Provider ---

class CooldownTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  CooldownTimerNotifier() : super(0);

  void start() {
    _timer?.cancel();
    state = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state > 0) {
        state = state - 1;
      } else {
        _timer?.cancel();
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final cooldownTimerProvider =
    StateNotifierProvider.autoDispose<CooldownTimerNotifier, int>((ref) {
      return CooldownTimerNotifier();
    });

// --- Pending Signup State Providers (Kept for compilation and future production use) ---

class PendingSignupState {
  final bool isPending;
  final String? email;
  final String? username;

  PendingSignupState({required this.isPending, this.email, this.username});

  factory PendingSignupState.idle() => PendingSignupState(isPending: false);
  factory PendingSignupState.pending(String email, String? username) =>
      PendingSignupState(isPending: true, email: email, username: username);
}

class PendingSignupNotifier extends StateNotifier<PendingSignupState> {
  PendingSignupNotifier() : super(PendingSignupState.idle());

  void setPending({required String email, String? username}) {
    state = PendingSignupState.pending(email, username);
  }

  void clear() {
    state = PendingSignupState.idle();
  }
}

final pendingSignupProvider =
    StateNotifierProvider<PendingSignupNotifier, PendingSignupState>((ref) {
      return PendingSignupNotifier();
    });

final isEmailVerifiedProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider);
  return user != null;
});

final scanHistoryProvider = FutureProvider<List<UrlScanModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  final scanService = UrlScanService();
  return await scanService.getUserScans(user.userId);
});

final recentScansProvider = FutureProvider<List<UrlScanModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  final scanService = UrlScanService();
  return await scanService.getRecentScans(userId: user.userId, limit: 5);
});

final dangerousScansProvider = FutureProvider<List<UrlScanModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  final scanService = UrlScanService();
  final scans = await scanService.getUserScans(user.userId);
  return scans.where((scan) {
    final verdict = scan.scanResult?.toLowerCase();
    return verdict == 'dangerous' || verdict == 'suspicious';
  }).toList();
});

final tabIndexProvider = StateProvider<int>((ref) => 0);
final settingsSectionProvider = StateProvider<int>((ref) => 0);
final alertsTabProvider = StateProvider<int>((ref) => 0);

// Accent color notifier
class AccentColorNotifier extends StateNotifier<Color> {
  AccentColorNotifier() : super(const Color(0xFF10B981)) {
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorVal = prefs.getInt('settings_accent_color');
      if (colorVal != null) {
        state = Color(colorVal);
      }
    } catch (_) {}
  }

  @override
  set state(Color value) {
    super.state = value;
    _saveAccentColor(value);
  }

  Future<void> _saveAccentColor(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('settings_accent_color', color.value);
    } catch (_) {}
  }
}

final accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  return AccentColorNotifier();
});
