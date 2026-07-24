import 'api_value_parser.dart';

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

  factory CommunityThreatModel.fromJson(Map<String, dynamic> json) {
    return CommunityThreatModel(
      threatId: apiString(json['threat_id'] ?? json['id']),
      threatName: apiNullableString(json['threat_name']),
      threatType: apiNullableString(json['threat_type']),
      description: apiNullableString(json['description']),
      severity: apiNullableString(json['severity']),
      reportedBy: apiNullableString(json['reported_by']),
      reportedAt: apiDateTime(json['reported_at']),
      url: apiNullableString(json['url']),
      blockedList: apiNullableString(json['blocked_list']),
      reportCount: apiInt(json['report_count']),
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
