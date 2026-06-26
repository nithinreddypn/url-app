class RazorpayWebPayment {
  static void open({
    required String key,
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String errorMessage) onFailure,
  }) {
    // Stub implementation does nothing.
    // Mobile runs the official Razorpay Flutter SDK directly.
    throw UnsupportedError('Razorpay Web SDK is not supported on this platform.');
  }
}
