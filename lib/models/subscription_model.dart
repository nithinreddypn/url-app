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

  static DateTime _parseUtc(String dateStr) {
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      final normalized = dateStr.replaceAll(' ', 'T');
      return DateTime.parse('${normalized}Z').toLocal();
    }
    return DateTime.parse(dateStr).toLocal();
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      subscriptionId: json['subscription_id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      status: json['status'] as String? ?? 'pending',
      paymentProvider: json['payment_provider'] as String? ?? 'razorpay',
      paymentId: json['payment_id'] as String?,
      orderId: json['order_id'] as String?,
      paymentSignature: json['payment_signature'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      startDate: json['start_date'] != null
          ? _parseUtc(json['start_date'] as String)
          : null,
      expiryDate: json['expiry_date'] != null
          ? _parseUtc(json['expiry_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? _parseUtc(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? _parseUtc(json['updated_at'] as String)
          : null,
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

  bool get isActive => status == 'active' && (expiryDate == null || expiryDate!.isAfter(DateTime.now()));
}
