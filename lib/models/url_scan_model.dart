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

  static DateTime _parseUtc(String dateStr) {
    // Supabase returns naive timestamps like '2026-06-25 07:54:54.39986'
    // without timezone info. We need to treat them as UTC.
    final hasTimezone = dateStr.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(dateStr) ||
        RegExp(r'[+-]\d{4}$').hasMatch(dateStr);
    if (!hasTimezone) {
      final normalized = dateStr.replaceAll(' ', 'T');
      return DateTime.parse('${normalized}Z').toLocal();
    }
    return DateTime.parse(dateStr).toLocal();
  }

  factory UrlScanModel.fromJson(Map<String, dynamic> json) {
    return UrlScanModel(
      scanId: (json['scan_id'] ?? json['id']) as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['user_id'] as String?,
      scannedUrl: json['scanned_url'] as String? ?? '',
      scanResult: json['scan_result'] as String? ?? 'safe',
      threatType: json['threat_type'] as String?,
      riskScore: json['risk_score'] as int? ?? 0,
      scannedAt: json['scanned_at'] != null
          ? _parseUtc(json['scanned_at'] as String)
          : null,
      virusTotalFlags: json['virus_total_flags'] as int? ?? 0,
      heuristicHits: json['heuristic_hits'] as int? ?? 0,
      communityReports: json['community_reports'] as int? ?? 0,
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
  bool get isSafe => scanResult?.toLowerCase() == 'safe';

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
