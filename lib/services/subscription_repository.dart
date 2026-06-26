import '../models/subscription_model.dart';
import 'supabase_config.dart';

class SubscriptionRepository {
  final _client = SupabaseConfig.client;

  /// Fetch the current active subscription for the user from the subscriptions table.
  Future<SubscriptionModel?> getActiveSubscription(String userId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('expiry_date', ascending: false);

      if (response.isNotEmpty) {
        final firstMap = response.first;
        final model = SubscriptionModel.fromJson(firstMap);
        // Ensure it has not expired
        if (model.isActive) {
          return model;
        }
      }
    } catch (_) {}
    return null;
  }


  /// Calls the Supabase Edge Function to verify Razorpay signature and activate subscription.
  Future<bool> verifyPaymentAndUpgrade({
    required String planId,
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-payment',
        body: {
          'plan_id': planId,
          'payment_id': paymentId,
          'order_id': orderId,
          'signature': signature,
          'amount': amount,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
