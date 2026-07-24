import '../models/subscription_model.dart';
import '../models/api_value_parser.dart';
import 'api_client.dart';

class PaymentOrder {
  final String keyId;
  final String orderId;
  final int amountPaise;
  final String currency;

  const PaymentOrder({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
  });
}

class SubscriptionRepository {
  SubscriptionRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SubscriptionModel?> getActiveSubscription(String userId) async {
    final payments = await _client.get('payments');
    final items = payments['items'];
    if (items is! List) return null;
    final active = items
        .whereType<Map>()
        .where((item) => item['status'] == 'captured')
        .toList();
    if (active.isEmpty) return null;
    final payment = Map<String, dynamic>.from(active.first);
    final startDate = apiDateTime(payment['created_at']);
    return SubscriptionModel(
      subscriptionId: apiString(payment['subscription_id'] ?? payment['id']),
      userId: userId,
      planId: 'paid',
      status: 'active',
      paymentProvider: 'razorpay',
      startDate: startDate,
      expiryDate: startDate?.add(const Duration(days: 30)),
    );
  }

  Future<PaymentOrder> createPaymentOrder(String planId, {String? couponCode}) async {
    final payload = await _client.post(
      'payments/orders',
      body: {
        'plan': planId,
        if (couponCode != null && couponCode.isNotEmpty) 'coupon': couponCode,
      },
    );
    final key = apiNullableString(payload['key_id']);
    final orderId = apiNullableString(payload['order_id']);
    final amount = payload['amount_paise'] == null
        ? null
        : apiInt(payload['amount_paise']);
    if (key == null || orderId == null || amount == null) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    return PaymentOrder(
      keyId: key,
      orderId: orderId,
      amountPaise: amount,
      currency: apiString(payload['currency'], fallback: 'INR'),
    );
  }

  Future<bool> verifyPaymentAndUpgrade({
    required String userId,
    required String planId,
    required String paymentId,
    required String orderId,
    required String signature,
    required double amount,
  }) async {
    final payload = await _client.post(
      'payments/verify',
      body: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return payload['status'] == 'captured';
  }

  Future<Map<String, dynamic>> validateCoupon(String code) async {
    final payload = await _client.post(
      'payments/coupons/validate',
      body: {'code': code},
    );
    return Map<String, dynamic>.from(payload);
  }

  Future<bool> cancelActiveSubscription() async {
    final payload = await _client.post('payments/cancel');
    return payload['message'] != null;
  }
}
