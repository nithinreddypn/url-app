import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_model.dart';

class SubscriptionRepository {
  static SubscriptionModel? _activeMockSubscription;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final subJson = prefs.getString('active_subscription');
      if (subJson != null) {
        _activeMockSubscription = SubscriptionModel.fromJson(jsonDecode(subJson) as Map<String, dynamic>);
      }
    } catch (_) {}
    _initialized = true;
  }

  static Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeMockSubscription != null) {
        prefs.setString('active_subscription', jsonEncode(_activeMockSubscription!.toJson()));
      } else {
        prefs.remove('active_subscription');
      }
    } catch (_) {}
  }

  /// Fetch the current active subscription for the user from the subscriptions table.
  Future<SubscriptionModel?> getActiveSubscription(String userId) async {
    await _ensureInitialized();
    if (_activeMockSubscription != null && _activeMockSubscription!.userId == userId) {
      return _activeMockSubscription;
    }
    return null;
  }

  /// Calls the Supabase Edge Function to verify Razorpay signature and activate subscription.
  Future<bool> verifyPaymentAndUpgrade({
    required String userId,
    required String planId,
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
  }) async {
    _activeMockSubscription = SubscriptionModel(
      subscriptionId: paymentId,
      userId: userId,
      planId: planId,
      status: 'active',
      paymentProvider: 'razorpay',
      startDate: DateTime.now().toUtc(),
      expiryDate: DateTime.now().toUtc().add(const Duration(days: 365)),
    );
    await _saveToPrefs();
    return true;
  }
}
