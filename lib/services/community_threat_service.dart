import 'api_client.dart';

class CommunityThreatService {
  CommunityThreatService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Fetch all trending threat reports.
  Future<List<Map<String, dynamic>>> getTrending() async {
    try {
      final res = await _client.get('community-reports/trending');
      final list = res['items'] as List?;
      return list?.map((item) => Map<String, dynamic>.from(item as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch all top threat reports.
  Future<List<Map<String, dynamic>>> getTop() async {
    try {
      final res = await _client.get('community-reports/top');
      final list = res['items'] as List?;
      return list?.map((item) => Map<String, dynamic>.from(item as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch verified community reports.
  Future<List<Map<String, dynamic>>> getVerified() async {
    try {
      final res = await _client.get('community-reports/verified');
      final list = res['items'] as List?;
      return list?.map((item) => Map<String, dynamic>.from(item as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch categories list.
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final res = await _client.get('community-reports/categories');
      final list = res['items'] as List?;
      return list?.map((item) => Map<String, dynamic>.from(item as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Check reporting status of a URL.
  Future<Map<String, dynamic>> checkStatus(String url) async {
    try {
      final res = await _client.get('community-reports/status?url=${Uri.encodeComponent(url)}');
      return res;
    } catch (_) {
      return {'status': 'clean', 'data': null};
    }
  }

  /// Submit a new threat report.
  Future<void> submitReport({
    required String url,
    required String category,
    required String description,
    String? screenshotBase64,
  }) async {
    await _client.post(
      'community-reports',
      body: {
        'url': url,
        'threat_category': category,
        'description': description,
        'screenshot_base64': screenshotBase64 ?? '',
      },
    );
  }

  /// Vote confirm_threat or looks_safe on a report.
  Future<void> submitVote({
    required String reportId,
    required String voteType,
  }) async {
    if (reportId.trim().isEmpty) {
      throw const ApiException(
        422,
        ApiFailureKind.validation,
        safeMessage: 'Invalid Report ID. You cannot vote on this item.',
      );
    }
    if (voteType != 'confirm_threat' && voteType != 'looks_safe') {
      throw const ApiException(
        422,
        ApiFailureKind.validation,
        safeMessage: 'Invalid Vote Type.',
      );
    }
    await _client.post(
      'community-reports/vote',
      body: {
        'report_id': reportId,
        'vote_type': voteType,
      },
    );
  }

  /// Fetch reports for the admin review queue.
  Future<List<Map<String, dynamic>>> getAdminReports(String tab) async {
    try {
      final res = await _client.get('admin/community-reports?tab=$tab');
      final list = res['items'] as List?;
      return list?.map((item) => Map<String, dynamic>.from(item as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Approve report.
  Future<void> approveReport(String reportId) async {
    await _client.post('admin/community-reports/$reportId/approve');
  }

  /// Reject report.
  Future<void> rejectReport(String reportId) async {
    await _client.post('admin/community-reports/$reportId/reject');
  }

  /// Block reporter.
  Future<void> blockReporter(String userId) async {
    await _client.post('admin/reporters/$userId/block');
  }

  /// Get the current user's reporter reputation.
  Future<Map<String, dynamic>> getMyReputation() async {
    try {
      return await _client.get('community-reports/my-reputation');
    } catch (_) {
      return {
        'trust_score': 50,
        'badge': 'Newcomer',
        'approved_reports': 0,
        'rejected_reports': 0,
        'false_reports': 0,
        'total_reports_submitted': 0,
        'total_votes_cast': 0,
      };
    }
  }

  /// Get the current user's own reports with timeline.
  Future<List<Map<String, dynamic>>> getMyReports() async {
    try {
      final result = await _client.get('community-reports/my-reports');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get detailed report view with timeline, votes, sources.
  Future<Map<String, dynamic>> getReportDetail(String reportId) async {
    final result = await _client.get('community-reports/$reportId/detail');
    return Map<String, dynamic>.from(result['report'] ?? {});
  }

  /// Get latest community reports.
  Future<List<Map<String, dynamic>>> getLatestReports() async {
    try {
      final result = await _client.get('community-reports/latest');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get threat intelligence feed.
  Future<List<Map<String, dynamic>>> getFeed() async {
    try {
      final result = await _client.get('community-reports/feed');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get community alerts.
  Future<List<Map<String, dynamic>>> getAlerts() async {
    try {
      final result = await _client.get('community-reports/alerts');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get pending verification reports.
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final result = await _client.get('community-reports/pending');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get most reported URLs.
  Future<List<Map<String, dynamic>>> getMostReported() async {
    try {
      final result = await _client.get('community-reports/most-reported');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get recently verified (approved) reports.
  Future<List<Map<String, dynamic>>> getRecentlyVerified() async {
    try {
      final result = await _client.get('community-reports/recently-verified');
      return List<Map<String, dynamic>>.from(result['items'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get community statistics.
  Future<Map<String, dynamic>> getCommunityStats() async {
    try {
      return await _client.get('community-reports/stats');
    } catch (_) {
      return {
        'total_reports': 0,
        'verified_count': 0,
        'pending_count': 0,
        'rejected_count': 0,
        'active_reporters': 0,
        'avg_confidence': 0.0,
        'total_votes': 0,
        'category_breakdown': [],
      };
    }
  }

  /// Merge a duplicate report into a primary target report.
  Future<void> mergeReport({required String reportId, required String targetId}) async {
    await _client.post('admin/community-reports/$reportId/merge', body: {'target_id': targetId});
  }
}
