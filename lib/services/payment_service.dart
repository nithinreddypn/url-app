import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;
  bool _isInitialized = false;

  PaymentService() {
    if (!kIsWeb) {
      _razorpay = Razorpay();
    }
  }

  void initialize({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    if (kIsWeb) return;
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
    _isInitialized = true;
  }

  void dispose() {
    if (!kIsWeb && _isInitialized) {
      _razorpay.clear();
    }
  }

  void openCheckout({
    required String key,
    required double amount, // In rupees (e.g. 99.00)
    required String name,
    required String description,
    required String email,
    required String contact,
    String? orderId,
  }) {
    if (kIsWeb) {
      // Razorpay Flutter plugin does not support web out of the box.
      // Throw an UnsupportedError so the UI can catch it and handle mock checkout gracefully.
      throw UnsupportedError('Razorpay Mobile SDK is not supported on Web platforms.');
    }

    var options = {
      'key': key,
      'amount': (amount * 100).toInt(), // Convert to paise
      'name': name,
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    _razorpay.open(options);
  }
}
