import 'api_value_parser.dart';

class UrlScanModel {
  final String scanId;
  final String? userId;
  final String scannedUrl;
  final String? scanResult;
  final String? threatType;
  final int? riskScore;
  final DateTime? scannedAt;
  final int virusTotalFlags;
  final int heuristicHits;
  final int communityReports;

  UrlScanModel({
    required this.scanId,
    this.userId,
    required this.scannedUrl,
    this.scanResult,
    this.threatType,
    this.riskScore,
    this.scannedAt,
    this.virusTotalFlags = 0,
    this.heuristicHits = 0,
    this.communityReports = 0,
  });

  factory UrlScanModel.fromJson(Map<String, dynamic> json) {
    return UrlScanModel(
      scanId: apiString(
        json['scan_id'] ?? json['id'],
        fallback: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      userId: apiNullableString(json['user_id']),
      scannedUrl: apiString(json['scanned_url'] ?? json['url']),
      scanResult: apiString(
        json['scan_result'] ?? json['verdict'],
        fallback: 'pending',
      ),
      threatType: apiNullableString(
        json['threat_type'] ?? json['threat_category'],
      ),
      riskScore: apiInt(json['risk_score']),
      scannedAt: apiDateTime(json['scanned_at'] ?? json['created_at']),
      virusTotalFlags: apiInt(json['virus_total_flags']),
      heuristicHits: apiInt(json['heuristic_hits']),
      communityReports: apiInt(json['community_reports']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scan_id': scanId,
      'user_id': userId,
      'scanned_url': scannedUrl,
      'scan_result': scanResult,
      'threat_type': threatType,
      'risk_score': riskScore,
      'scanned_at': scannedAt?.toIso8601String(),
      'virus_total_flags': virusTotalFlags,
      'heuristic_hits': heuristicHits,
      'community_reports': communityReports,
    };
  }

  /// Whether this scan result indicates the URL is safe.
  /// Whether this scan result indicates the URL is safe.
  /// A URL is safe if the verdict is 'safe', or if the risk score is low
  /// and there are no VirusTotal flags.
  bool get isSafe {
    final verdict = scanResult?.toLowerCase() ?? '';
    if (verdict == 'safe') return true;
    if (verdict == 'dangerous') return false;
    // For pending/unknown results, use risk score and flags as heuristic
    if ((riskScore ?? 0) <= 20 && virusTotalFlags == 0) return true;
    return false;
  }

  /// Whether this scan result indicates the URL is dangerous.
  bool get isDangerous => scanResult?.toLowerCase() == 'dangerous';

  /// Returns a human-readable risk level based on the risk score.
  String get riskLevel {
    if (riskScore == null) return 'Unknown';
    if (riskScore! <= 20) return 'Low';
    if (riskScore! <= 50) return 'Medium';
    if (riskScore! <= 80) return 'High';
    return 'Critical';
  }
}
