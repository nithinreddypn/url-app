import 'api_value_parser.dart';

class SubscriptionModel {
  final String subscriptionId;
  final String userId;
  final String planId;
  final String status; // pending, active, expired, cancelled
  final String paymentProvider;
  final String? paymentId;
  final String? orderId;
  final String? paymentSignature;
  final double? amount;
  final String currency;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionModel({
    required this.subscriptionId,
    required this.userId,
    required this.planId,
    this.status = 'pending',
    this.paymentProvider = 'razorpay',
    this.paymentId,
    this.orderId,
    this.paymentSignature,
    this.amount,
    this.currency = 'INR',
    this.startDate,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      subscriptionId: apiString(json['subscription_id'] ?? json['id']),
      userId: apiString(json['user_id']),
      planId: apiString(json['plan_id']),
      status: apiString(json['status'], fallback: 'pending'),
      paymentProvider: apiString(
        json['payment_provider'],
        fallback: 'razorpay',
      ),
      paymentId: apiNullableString(json['payment_id']),
      orderId: apiNullableString(json['order_id']),
      paymentSignature: apiNullableString(json['payment_signature']),
      amount: json['amount'] == null ? null : apiDouble(json['amount']),
      currency: apiString(json['currency'], fallback: 'INR'),
      startDate: apiDateTime(json['start_date']),
      expiryDate: apiDateTime(json['expiry_date']),
      createdAt: apiDateTime(json['created_at']),
      updatedAt: apiDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subscription_id': subscriptionId,
      'user_id': userId,
      'plan_id': planId,
      'status': status,
      'payment_provider': paymentProvider,
      'payment_id': paymentId,
      'order_id': orderId,
      'payment_signature': paymentSignature,
      'amount': amount,
      'currency': currency,
      'start_date': startDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  bool get isActive =>
      status == 'active' &&
      (expiryDate == null || expiryDate!.isAfter(DateTime.now()));
}
