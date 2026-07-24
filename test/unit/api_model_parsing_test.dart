import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/models/plan_model.dart';
import 'package:url_defender/models/url_lookup_result.dart';
import 'package:url_defender/models/url_scan_model.dart';
import 'package:url_defender/models/user_model.dart';

void main() {
  test('user model accepts PHP/MySQL scalar encodings', () {
    final user = UserModel.fromJson({
      'id': 42,
      'full_name': 'Nexa User',
      'email': 'user@example.com',
      'is_premium': '1',
      'lifetime_scan_count': '17',
      'blocked_list': '["bad.example"]',
      'created_at': '2026-07-16 10:30:00',
    });

    expect(user.userId, '42');
    expect(user.username, 'Nexa User');
    expect(user.isPremium, isTrue);
    expect(user.lifetimeScanCount, 17);
    expect(user.blockedList, ['bad.example']);
    expect(user.createdAt, isNotNull);
  });

  test('scan and plan models accept numeric strings and JSON features', () {
    final scan = UrlScanModel.fromJson({
      'id': 9,
      'url': 'https://example.com',
      'verdict': 'safe',
      'risk_score': '4',
      'virus_total_flags': '1',
    });
    final plan = PlanModel.fromJson({
      'id': 'team',
      'name': 'Team',
      'price': '499.00',
      'is_active': '1',
      'features': '["Realtime alerts","Shared history"]',
    });

    expect(scan.scanId, '9');
    expect(scan.riskScore, 4);
    expect(scan.virusTotalFlags, 1);
    expect(plan.price, 499);
    expect(plan.isActive, isTrue);
    expect(plan.features, hasLength(2));
  });

  test('URL lookup accepts integer boolean values', () {
    final result = UrlLookupResult.fromJson({
      'exists': 1,
      'already_in_history': '1',
      'analysis': {
        'url': 'example.com',
        'status': 'safe',
        'risk_score': '2',
        'redirect_count': '1',
      },
    });

    expect(result.exists, isTrue);
    expect(result.alreadyInHistory, isTrue);
    expect(result.analysis?.riskScore, 2);
    expect(result.analysis?.redirectCount, 1);
  });
}
