import 'api_value_parser.dart';

class UrlLookupAnalysis {
  const UrlLookupAnalysis({
    required this.url,
    required this.status,
    required this.riskScore,
    required this.category,
    required this.threatType,
    required this.sslStatus,
    required this.redirectCount,
    required this.source,
  });

  final String url;
  final String status;
  final int riskScore;
  final String category;
  final String? threatType;
  final String sslStatus;
  final int redirectCount;
  final String source;

  factory UrlLookupAnalysis.fromJson(Map<String, dynamic> json) {
    return UrlLookupAnalysis(
      url: json['url']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'unknown',
      riskScore: apiInt(json['risk_score']),
      category: json['category']?.toString() ?? 'Unknown',
      threatType: json['threat_type']?.toString(),
      sslStatus: json['ssl_status']?.toString() ?? 'none',
      redirectCount: apiInt(json['redirect_count']),
      source: json['source']?.toString() ?? 'URL Defender Threat Intelligence',
    );
  }
}

class UrlLookupResult {
  const UrlLookupResult({
    required this.exists,
    this.analysis,
    this.alreadyInHistory = false,
    this.lastScanned,
    this.scanId,
  });

  final bool exists;
  final UrlLookupAnalysis? analysis;
  final bool alreadyInHistory;
  final DateTime? lastScanned;
  final String? scanId;

  factory UrlLookupResult.fromJson(Map<String, dynamic> json) {
    final rawAnalysis = json['analysis'];
    return UrlLookupResult(
      exists: apiBool(json['exists']),
      analysis: rawAnalysis is Map
          ? UrlLookupAnalysis.fromJson(Map<String, dynamic>.from(rawAnalysis))
          : null,
      alreadyInHistory: apiBool(json['already_in_history']),
      lastScanned: apiDateTime(json['last_scanned']),
      scanId: apiNullableString(json['scan_id']),
    );
  }
}
