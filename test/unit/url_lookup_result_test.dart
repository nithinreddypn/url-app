import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/models/url_lookup_result.dart';

void main() {
  test('parses sanitized cached threat intelligence', () {
    final result = UrlLookupResult.fromJson({
      'exists': true,
      'already_in_history': true,
      'last_scanned': '2026-07-16T08:00:00Z',
      'scan_id': 'owned-scan',
      'analysis': {
        'url': 'example.com',
        'status': 'dangerous',
        'risk_score': 90,
        'category': 'malicious',
        'threat_type': 'phishing',
        'ssl_status': 'valid',
        'redirect_count': 2,
        'source': 'URL Defender Threat Intelligence',
      },
    });

    expect(result.exists, isTrue);
    expect(result.alreadyInHistory, isTrue);
    expect(result.analysis?.status, 'dangerous');
    expect(result.analysis?.riskScore, 90);
    expect(result.analysis?.redirectCount, 2);
  });

  test('parses a cache miss without analysis', () {
    final result = UrlLookupResult.fromJson({'exists': false});
    expect(result.exists, isFalse);
    expect(result.analysis, isNull);
    expect(result.alreadyInHistory, isFalse);
  });
}
