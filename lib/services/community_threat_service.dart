import '../models/community_threat_model.dart';

class CommunityThreatService {
  static final List<CommunityThreatModel> _localThreats = [
    CommunityThreatModel(
      threatId: 'threat_1',
      threatName: 'PayPal Credential Harvester',
      threatType: 'phishing',
      description: 'Spoofed PayPal login page attempting to capture credentials and credit card details.',
      severity: 'critical',
      reportedBy: 'Nexabot',
      url: 'http://paypal-verification-secure.com/login',
      reportCount: 15,
      reportedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    CommunityThreatModel(
      threatId: 'threat_2',
      threatName: 'Ransomware Dropper Script',
      threatType: 'malware',
      description: 'Host serving a malicious JS file that executes a silent drive-by download of LockBit payload.',
      severity: 'critical',
      reportedBy: 'Defender',
      url: 'http://cdn-update-java.net/patch.js',
      reportCount: 22,
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    CommunityThreatModel(
      threatId: 'threat_3',
      threatName: 'Fake Amazon Gift Card Hub',
      threatType: 'scam',
      description: 'Interactive survey scam promising \$1000 gift cards to extract personal phone numbers.',
      severity: 'medium',
      reportedBy: 'SafetyAgent',
      url: 'http://amazon-survey-rewards.xyz/claim',
      reportCount: 8,
      reportedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  /// Fetch all community-reported threats.
  Future<List<CommunityThreatModel>> getThreats({int limit = 50}) async {
    return _localThreats.take(limit).toList();
  }

  /// Report a new community threat.
  Future<CommunityThreatModel> reportThreat({
    String? threatName,
    String? threatType,
    String? description,
    String? severity,
    String? reportedBy,
    String? url,
  }) async {
    final newThreat = CommunityThreatModel(
      threatId: DateTime.now().millisecondsSinceEpoch.toString(),
      threatName: threatName ?? 'Reported Threat',
      threatType: threatType ?? 'suspicious',
      description: description ?? 'Reported by user',
      severity: severity ?? 'medium',
      reportedBy: reportedBy ?? 'Guest',
      url: url ?? '',
      reportCount: 1,
      reportedAt: DateTime.now(),
    );
    _localThreats.insert(0, newThreat);
    return newThreat;
  }

  /// Get a threat by its URL (unique constraint).
  Future<CommunityThreatModel?> getThreatByUrl(String url) async {
    try {
      return _localThreats.firstWhere((threat) => threat.url == url);
    } catch (_) {
      return null;
    }
  }

  /// Get a threat by its ID.
  Future<CommunityThreatModel?> getThreatById(String threatId) async {
    try {
      return _localThreats.firstWhere((threat) => threat.threatId == threatId);
    } catch (_) {
      return null;
    }
  }

  /// Increment the report count for an existing threat.
  Future<CommunityThreatModel> incrementReportCount(String threatId) async {
    final threatIdx = _localThreats.indexWhere((t) => t.threatId == threatId);
    if (threatIdx == -1) throw Exception('Threat not found');

    final threat = _localThreats[threatIdx];
    final updated = CommunityThreatModel(
      threatId: threat.threatId,
      threatName: threat.threatName,
      threatType: threat.threatType,
      description: threat.description,
      severity: threat.severity,
      reportedBy: threat.reportedBy,
      url: threat.url,
      reportCount: threat.reportCount + 1,
      reportedAt: threat.reportedAt,
    );
    _localThreats[threatIdx] = updated;
    return updated;
  }

  /// Get threats filtered by severity (e.g., 'critical', 'high', 'medium', 'low').
  Future<List<CommunityThreatModel>> getThreatsBySeverity(String severity) async {
    return _localThreats.where((t) => t.severity == severity).toList();
  }

  /// Get threats filtered by type (e.g., 'phishing', 'malware').
  Future<List<CommunityThreatModel>> getThreatsByType(String type) async {
    return _localThreats.where((t) => t.threatType == type).toList();
  }

  /// Delete a threat by its ID.
  Future<void> deleteThreat(String threatId) async {
    _localThreats.removeWhere((t) => t.threatId == threatId);
  }

  /// Listen to real-time threat updates.
  Stream<List<Map<String, dynamic>>> onThreatUpdates() {
    return Stream.value(_localThreats.map((t) => t.toJson()).toList());
  }
}
