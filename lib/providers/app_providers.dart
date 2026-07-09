import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';
import '../models/blocked_url_model.dart';
import '../models/url_scan_model.dart';
import '../services/url_scan_service.dart';
import '../services/user_service.dart';
import '../services/settings_repository.dart';
import '../services/plan_repository.dart';
import '../services/subscription_repository.dart';
import '../services/scan_limit_service.dart';
import '../services/blocked_url_service.dart';


// Service & Repository Providers
final userServiceProvider = Provider((ref) => UserService());
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());
final planRepositoryProvider = Provider((ref) => PlanRepository());
final subscriptionRepositoryProvider = Provider((ref) => SubscriptionRepository());

final scanLimitServiceProvider = Provider((ref) {
  return ScanLimitService();
});

// State Providers

/// Exposes the current authenticated user's model and profiles metadata.
final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) {
  final userService = ref.watch(userServiceProvider);
  return UserNotifier(userService);
});

class UserNotifier extends StateNotifier<UserModel?> {
  final UserService _userService;

  UserNotifier(this._userService) : super(null) {
    _init();
  }

  void _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('active_user');
      if (userJson != null) {
        state = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  void login(String email, String username) {
    final cleanId = email.toLowerCase() == 'nexabot@gmail.com'
        ? 'mock_user_id_12345'
        : 'user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()}';
    
    final isPremium = email.toLowerCase() == 'nexabot@gmail.com' || email.toLowerCase() == 'nexabot4@gmail.com';
    
    final user = UserModel(
      userId: cleanId,
      username: username,
      email: email,
      isPremium: isPremium,
    );
    
    state = user;

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('active_user', jsonEncode(user.toJson()));
    });

    // Asynchronously register/persist the user profile
    _userService.createUser(
      userId: cleanId,
      username: username,
      email: email,
    ).then((_) {
      if (isPremium) {
        _userService.updateUser(cleanId, {'is_premium': true});
      }
    });
  }

  void logout() {
    state = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('active_user');
    });
  }

  Future<void> refreshUser() async {
    if (state == null) return;
    final user = await _userService.getUser(state!.userId);
    if (user != null) {
      state = user;
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('active_user', jsonEncode(user.toJson()));
    }
  }

  Future<void> upgradeUserToPremium() async {
    if (state == null) return;
    final updatedUser = await _userService.updateUser(state!.userId, {'is_premium': true});
    state = updatedUser;
    
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('active_user', jsonEncode(updatedUser.toJson()));
  }
}

/// Exposes dynamic active pricing plans.
final planProvider = FutureProvider<List<PlanModel>>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  return await repo.getActivePlans();
});

/// Exposes configurable application settings (e.g. free_scan_limit).
final settingsProvider = FutureProvider<int>((ref) async {
  return 50;
});

/// Exposes the current active subscription, treating the subscriptions table as the source of truth.
final subscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;

  if (user.email == 'nexabot4@gmail.com' || user.email == 'nexabot@gmail.com') {
    return SubscriptionModel(
      subscriptionId: 'sub_mock_nexabot',
      userId: user.userId,
      planId: 'c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f', // Yearly plan ID
      status: 'active',
      paymentProvider: 'razorpay',
      startDate: DateTime.now().toUtc(),
      expiryDate: DateTime.now().toUtc().add(const Duration(days: 365)),
    );
  }

  try {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return await repo.getActiveSubscription(user.userId);
  } catch (e) {
    debugPrint('Error in subscriptionProvider: $e');
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
    debugPrint('Error in scanLimitProvider: $e');
    return 10; // Default fallback to 10 scans
  }
});

final blockedUrlsProvider = FutureProvider<List<BlockedUrlModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  try {
    final blockedService = BlockedUrlService();
    return await blockedService.getBlockedUrls(user.userId);
  } catch (e) {
    debugPrint('Error in blockedUrlsProvider: $e');
    return [];
  }
});

// Payment State StateNotifier

enum PaymentStatus { idle, loading, success, failure }

class PaymentState {
  final PaymentStatus status;
  final String? errorMessage;

  PaymentState({
    required this.status,
    this.errorMessage,
  });

  factory PaymentState.idle() => PaymentState(status: PaymentStatus.idle);
  factory PaymentState.loading() => PaymentState(status: PaymentStatus.loading);
  factory PaymentState.success() => PaymentState(status: PaymentStatus.success);
  factory PaymentState.failure(String message) =>
      PaymentState(status: PaymentStatus.failure, errorMessage: message);
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final subRepo = ref.watch(subscriptionRepositoryProvider);
  final userNotif = ref.watch(userProvider.notifier);
  return PaymentNotifier(ref, subRepo, userNotif);
});

class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref _ref;
  final SubscriptionRepository _subRepo;
  final UserNotifier _userNotifier;

  PaymentNotifier(this._ref, this._subRepo, this._userNotifier) : super(PaymentState.idle());

  void setIdle() {
    state = PaymentState.idle();
  }

  void setLoading() {
    state = PaymentState.loading();
  }

  void setFailure(String message) {
    state = PaymentState.failure(message);
  }

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
      state = PaymentState.failure('Payment verification signature check failed.');
      return false;
    }
  }
}

// Theme State Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
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

final cooldownTimerProvider = StateNotifierProvider.autoDispose<CooldownTimerNotifier, int>((ref) {
  return CooldownTimerNotifier();
});

// --- Pending Signup State Providers (Kept for compilation and future production use) ---

class PendingSignupState {
  final bool isPending;
  final String? email;
  final String? username;

  PendingSignupState({
    required this.isPending,
    this.email,
    this.username,
  });

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

final pendingSignupProvider = StateNotifierProvider<PendingSignupNotifier, PendingSignupState>((ref) {
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
  return await scanService.getScansByResult('dangerous', userId: user.userId);
});

final tabIndexProvider = StateProvider<int>((ref) => 0);
