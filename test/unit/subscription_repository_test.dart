import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/api_client.dart';
import 'package:url_defender/services/subscription_repository.dart';

class _PaymentApiClient extends ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
  }) async => {
    'items': [
      {
        'id': 101,
        'subscription_id': 202,
        'status': 'captured',
        'created_at': '2026-07-01 00:00:00',
      },
    ],
  };
}

void main() {
  test(
    'subscription dates are derived from the API payment timestamp',
    () async {
      final repository = SubscriptionRepository(client: _PaymentApiClient());

      final subscription = await repository.getActiveSubscription('user-1');

      expect(subscription, isNotNull);
      expect(subscription?.subscriptionId, '202');
      expect(
        subscription?.expiryDate?.difference(subscription.startDate!),
        const Duration(days: 30),
      );
    },
  );
}
