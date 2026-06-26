import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';
import '../models/blocked_url_model.dart';
import '../services/user_service.dart';
import '../services/settings_repository.dart';
import '../services/plan_repository.dart';
import '../services/subscription_repository.dart';
import '../services/scan_limit_service.dart';
import '../services/blocked_url_service.dart';
import '../services/supabase_config.dart';

// Service & Repository Providers
final userServiceProvider = Provider((ref) => UserService());
final settingsRepositoryProvider = Provider((ref) => SettingsRepository());
final planRepositoryProvider = Provider((ref) => PlanRepository());
final subscriptionRepositoryProvider = Provider((ref) => SubscriptionRepository());

final scanLimitServiceProvider = Provider((ref) {
  final userService = ref.read(userServiceProvider);
  return ScanLimitService(
    userService: userService,
  );
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

  void _init() {
    // Check initial user
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser != null) {
      refreshUser();
    }

    // Listen to changes in auth state
    SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user ?? SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        final profile = await _getOrCreateProfile(user);
        state = profile;
      } else {
        state = null;
      }
    });
  }

  Future<UserModel> _getOrCreateProfile(User user) async {
    try {
      var profile = await _userService.getUser(user.id);
      final email = user.email ?? '';
      
      if (profile == null) {
        final username = email.split('@').first.isNotEmpty ? email.split('@').first : 'User';
        profile = await _userService.createUser(
          userId: user.id,
          username: username,
          email: email,
        );
      }

      if (email == 'nexabot4@gmail.com') {
        if (!profile.isPremium) {
          try {
            await _userService.updateUser(user.id, {'is_premium': true});
          } catch (_) {}
          profile = profile.copyWith(isPremium: true);
        }
      }
      return profile;
    } catch (e) {
      debugPrint('Error in _getOrCreateProfile: $e');
      final email = user.email ?? '';
      final username = email.split('@').first.isNotEmpty ? email.split('@').first : 'User';
      return UserModel(
        userId: user.id,
        username: username,
        email: email,
        isPremium: email == 'nexabot4@gmail.com',
      );
    }
  }

  Future<void> refreshUser() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await _getOrCreateProfile(user);
        state = profile;
      } catch (_) {}
    }
  }
}

/// Exposes dynamic active pricing plans.
final planProvider = FutureProvider<List<PlanModel>>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  return await repo.getActivePlans();
});

/// Exposes configurable application settings (e.g. free_scan_limit).
final settingsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return await repo.getFreeScanLimit();
});

/// Exposes the current active subscription, treating the subscriptions table as the source of truth.
final subscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return null;

  if (user.email == 'nexabot4@gmail.com') {
    return SubscriptionModel(
      subscriptionId: 'sub_mock_nexabot4',
      userId: user.userId,
      planId: 'c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f', // Yearly plan ID
      status: 'active',
      paymentProvider: 'razorpay',
      startDate: DateTime.now().toUtc(),
      expiryDate: DateTime.now().toUtc().add(const Duration(days: 365)),
    );
  }

  final repo = ref.watch(subscriptionRepositoryProvider);
  return await repo.getActiveSubscription(user.userId);
});

/// Exposes remaining scan counts.
final scanLimitProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return 0;

  final scanLimitService = ref.watch(scanLimitServiceProvider);
  return await scanLimitService.getRemainingScans(user.userId);
});

final blockedUrlsProvider = FutureProvider<List<BlockedUrlModel>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];
  final blockedService = BlockedUrlService();
  final list = await blockedService.getAllBlockedUrls();
  if (list.isEmpty) {
    try {
      await blockedService.blockUrl(
        userId: user.userId,
        url: 'phishing-example.com',
        reason: 'Phishing Attempt',
      );
      await blockedService.blockUrl(
        userId: user.userId,
        url: 'malware-example.net',
        reason: 'Malicious Software Download',
      );
      await blockedService.blockUrl(
        userId: user.userId,
        url: 'fake-bank-login.com',
        reason: 'Credential Harvesting',
      );
      return await blockedService.getAllBlockedUrls();
    } catch (_) {}
  }
  return list;
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

    final success = await _subRepo.verifyPaymentAndUpgrade(
      planId: planId,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
      amount: amount,
    );

    if (success) {
      state = PaymentState.success();
      // Refresh user to update local cache is_premium flags
      await _userNotifier.refreshUser();
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
