import 'package:http/http.dart' as http;

import '../models/url_lookup_result.dart';
import '../models/url_scan_model.dart';
import '../models/api_value_parser.dart';
import 'api_client.dart';

class UrlScanService {
  UrlScanService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  http.Client? _lookupClient;
  String? _lastLookupKey;
  UrlLookupResult? _lastLookupResult;

  static int getLocalScansCount(String userId) => 0;

  Future<UrlLookupResult> lookupUrl({
    required String userId,
    required String url,
  }) async {
    final key = _lookupKey(url);
    if (key.isEmpty) {
      return const UrlLookupResult(exists: false);
    }
    if (_lastLookupKey == key && _lastLookupResult != null) {
      return _lastLookupResult!;
    }

    cancelLookup();
    final lookupClient = http.Client();
    _lookupClient = lookupClient;
    try {
      final payload = await _client.postWithClient(
        lookupClient,
        'url/lookup',
        body: {'url': url},
      );
      final result = UrlLookupResult.fromJson(payload);
      if (identical(_lookupClient, lookupClient)) {
        _lastLookupKey = key;
        _lastLookupResult = result;
        _lookupClient = null;
      }
      return result;
    } finally {
      if (identical(_lookupClient, lookupClient)) {
        _lookupClient = null;
      }
      lookupClient.close();
    }
  }

  void cancelLookup() {
    _lookupClient?.close();
    _lookupClient = null;
  }

  void clearLookupCache() {
    _lastLookupKey = null;
    _lastLookupResult = null;
  }

  void dispose() => cancelLookup();

  String _lookupKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');

  Future<UrlScanModel> scanUrl({
    required String userId,
    required String scannedUrl,
    String? scanResult,
    String? threatType,
    int? riskScore,
    int virusTotalFlags = 0,
    int heuristicHits = 0,
    int communityReports = 0,
  }) => scanUrlWithVirusTotal(scannedUrl: scannedUrl, userId: userId);

  /// Queues the URL on the server. VirusTotal credentials never reach Flutter.
  Future<UrlScanModel> scanUrlWithVirusTotal({
    required String scannedUrl,
    required String userId,
  }) async {
    final normalizedUrl =
        scannedUrl.startsWith('http://') || scannedUrl.startsWith('https://')
        ? scannedUrl
        : 'https://$scannedUrl';
    final created = await _client.post('scans', body: {'url': normalizedUrl});
    final scanId = apiNullableString(created['id']);
    if (scanId == null || scanId.isEmpty) {
      throw const ApiException(500, ApiFailureKind.invalidResponse);
    }
    final createdModel = _fromApi(Map<String, dynamic>.from(created), userId);
    if (createdModel.scanResult != 'pending') return createdModel;
    for (var attempt = 0; attempt < 12; attempt++) {
      final detail = await _client.get('scans/$scanId');
      final scan = apiMap(detail['scan']);
      if (scan != null) {
        final model = _fromApi(scan, userId);
        if (model.scanResult != 'pending') return model;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return createdModel;
  }

  Future<List<UrlScanModel>> getUserScans(String userId) async {
    final payload = await _client.get('scans?limit=100');
    return _items(payload, userId);
  }

  Future<UrlScanModel?> getScanById(
    String scanId, {
    required String userId,
  }) async {
    try {
      final payload = await _client.get('scans/$scanId');
      final scan = apiMap(payload['scan']);
      return scan == null ? null : _fromApi(scan, userId);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<UrlScanModel>> getRecentScans({
    required String userId,
    int limit = 20,
  }) async {
    final payload = await _client.get('scans?limit=$limit');
    return _items(payload, userId);
  }

  Future<List<UrlScanModel>> getScansByResult(
    String result, {
    required String userId,
  }) async {
    final payload = await _client.get('scans?limit=100&verdict=$result');
    return _items(payload, userId);
  }

  Future<void> deleteScan(String scanId, {required String userId}) async {
    if (scanId == 'all') {
      final scans = await getUserScans(userId);
      for (final scan in scans) {
        await _client.delete('scans/${scan.scanId}');
      }
      return;
    }
    await _client.delete('scans/$scanId');
  }

  Future<int> getUserScanCount(String userId) async {
    final payload = await _client.get('usage');
    return apiInt(payload['scans_used']);
  }

  Stream<List<Map<String, dynamic>>> onNewScans({
    required String userId,
  }) async* {
    final scans = await getUserScans(userId);
    yield scans.map((scan) => scan.toJson()).toList();
  }

  List<UrlScanModel> _items(Map<String, dynamic> payload, String userId) {
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => _fromApi(Map<String, dynamic>.from(item), userId))
        .toList();
  }

  UrlScanModel _fromApi(Map<String, dynamic> scan, String userId) {
    final result = scan['result'];
    final resultMap = result is Map
        ? Map<String, dynamic>.from(result)
        : const <String, dynamic>{};
    return UrlScanModel.fromJson({
      ...scan,
      'user_id': userId,
      'virus_total_flags': scan['virus_total_flags'] ?? resultMap['blacklist_listed'] ?? 0,
      'heuristic_hits': scan['heuristic_hits'] ?? resultMap['heuristic_hits'] ?? 0,
      'community_reports': scan['community_reports'] ?? resultMap['blacklist_total'] ?? 0,
    });
  }
}
