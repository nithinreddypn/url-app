// ignore_for_file: avoid_web_libraries_in_flutter, undefined_function, undefined_method, deprecated_member_use
import 'dart:js';

class RazorpayWebPayment {
  static void open({
    required String key,
    required double amount,
    required String name,
    required String description,
    required String email,
    required String contact,
    required String orderId,
    required Function(String paymentId, String orderId, String signature) onSuccess,
    required Function(String errorMessage) onFailure,
  }) {
    void startCheckoutFlow() {
      // Razorpay expectations: amount in paise (e.g., Rs 99 -> 9900 paise)
      final options = JsObject.jsify({
        'key': key,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'order_id': orderId,
        'name': name,
        'description': description,
        'prefill': {
          'email': email,
          'contact': contact,
        },
        'theme': {
          'color': '#10B981', // Emerald green
        },
        'handler': allowInterop((response) {
          final paymentId = response['razorpay_payment_id'] ?? '';
          final orderId = response['razorpay_order_id'] ?? '';
          final signature = response['razorpay_signature'] ?? '';
          onSuccess(paymentId, orderId, signature);
        }),
        'modal': {
          'ondismiss': allowInterop(() {
            onFailure('Payment cancelled by user.');
          }),
        },
      });

      final razorpayConstructor = context['Razorpay'];
      if (razorpayConstructor == null) {
        onFailure('Payment service is temporarily unavailable.');
        return;
      }

      final rzp = JsObject(razorpayConstructor, [options]);
      rzp.callMethod('open');
    }

    if (context['Razorpay'] != null) {
      startCheckoutFlow();
    } else {
      // Dynamically load the SDK script tag in browser
      try {
        final doc = context['document'];
        if (doc != null) {
          final script = doc.callMethod('createElement', ['script']);
          script['type'] = 'text/javascript';
          script['src'] = 'https://checkout.razorpay.com/v1/checkout.js';
          script['async'] = true;
          
          script['onload'] = allowInterop(() {
            startCheckoutFlow();
          });
          
          script['onerror'] = allowInterop(() {
            onFailure('Payment service is temporarily unavailable.');
          });

          final head = doc['head'] ?? doc.callMethod('getElementsByTagName', ['head'])[0];
          head.callMethod('appendChild', [script]);
        } else {
          onFailure('Payment service is temporarily unavailable.');
        }
      } catch (_) {
        onFailure('Payment service is temporarily unavailable.');
      }
    }
  }
}
