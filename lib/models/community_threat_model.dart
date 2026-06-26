class CommunityThreatModel {
  final String threatId;
  final String? threatName;
  final String? threatType;
  final String? description;
  final String? severity;
  final String? reportedBy;
  final DateTime? reportedAt;
  final String? url;
  final String? blockedList;
  final int reportCount;

  CommunityThreatModel({
    required this.threatId,
    this.threatName,
    this.threatType,
    this.description,
    this.severity,
    this.reportedBy,
    this.reportedAt,
    this.url,
    this.blockedList,
    this.reportCount = 0,
  });

  static DateTime _parseUtc(String dateStr) {
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      final normalized = dateStr.replaceAll(' ', 'T');
      return DateTime.parse('${normalized}Z').toLocal();
    }
    return DateTime.parse(dateStr).toLocal();
  }

  factory CommunityThreatModel.fromJson(Map<String, dynamic> json) {
    return CommunityThreatModel(
      threatId: json['threat_id'] as String,
      threatName: json['threat_name'] as String?,
      threatType: json['threat_type'] as String?,
      description: json['description'] as String?,
      severity: json['severity'] as String?,
      reportedBy: json['reported_by'] as String?,
      reportedAt: json['reported_at'] != null
          ? _parseUtc(json['reported_at'] as String)
          : null,
      url: json['url'] as String?,
      blockedList: json['blocked_list'] as String?,
      reportCount: json['report_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'threat_name': threatName,
      'threat_type': threatType,
      'description': description,
      'severity': severity,
      'reported_by': reportedBy,
      'url': url,
      'blocked_list': blockedList,
      'report_count': reportCount,
    };
  }

  /// Whether this threat is critical severity.
  bool get isCritical => severity?.toLowerCase() == 'critical';

  /// Whether this threat is high severity.
  bool get isHigh => severity?.toLowerCase() == 'high';
}
