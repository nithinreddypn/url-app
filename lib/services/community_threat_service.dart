import '../models/community_threat_model.dart';
import 'supabase_config.dart';

class CommunityThreatService {
  final _client = SupabaseConfig.client;
  static const _table = 'community_threats';

  /// Fetch all community-reported threats.
  Future<List<CommunityThreatModel>> getThreats({int limit = 50}) async {
    final response = await _client
        .from(_table)
        .select()
        .order('reported_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => CommunityThreatModel.fromJson(json))
        .toList();
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
    final response = await _client.from(_table).insert({
      'threat_name': threatName,
      'threat_type': threatType,
      'description': description,
      'severity': severity,
      'reported_by': reportedBy,
      'url': url,
      'report_count': 1,
    }).select().single();

    return CommunityThreatModel.fromJson(response);
  }

  /// Get a threat by its URL (unique constraint).
  Future<CommunityThreatModel?> getThreatByUrl(String url) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('url', url)
        .maybeSingle();

    if (response == null) return null;
    return CommunityThreatModel.fromJson(response);
  }

  /// Get a threat by its ID.
  Future<CommunityThreatModel?> getThreatById(String threatId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('threat_id', threatId)
        .maybeSingle();

    if (response == null) return null;
    return CommunityThreatModel.fromJson(response);
  }

  /// Increment the report count for an existing threat.
  Future<CommunityThreatModel> incrementReportCount(String threatId) async {
    // Fetch current count, then increment
    final threat = await getThreatById(threatId);
    if (threat == null) throw Exception('Threat not found');

    final response = await _client
        .from(_table)
        .update({'report_count': threat.reportCount + 1})
        .eq('threat_id', threatId)
        .select()
        .single();

    return CommunityThreatModel.fromJson(response);
  }

  /// Get threats filtered by severity (e.g., 'critical', 'high', 'medium', 'low').
  Future<List<CommunityThreatModel>> getThreatsBySeverity(String severity) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('severity', severity)
        .order('reported_at', ascending: false);

    return (response as List)
        .map((json) => CommunityThreatModel.fromJson(json))
        .toList();
  }

  /// Get threats filtered by type (e.g., 'phishing', 'malware').
  Future<List<CommunityThreatModel>> getThreatsByType(String type) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('threat_type', type)
        .order('reported_at', ascending: false);

    return (response as List)
        .map((json) => CommunityThreatModel.fromJson(json))
        .toList();
  }

  /// Delete a threat by its ID.
  Future<void> deleteThreat(String threatId) async {
    await _client.from(_table).delete().eq('threat_id', threatId);
  }

  /// Listen to real-time threat updates.
  Stream<List<Map<String, dynamic>>> onThreatUpdates() {
    return _client
        .from(_table)
        .stream(primaryKey: ['threat_id'])
        .order('reported_at', ascending: false)
        .limit(50);
  }
}
