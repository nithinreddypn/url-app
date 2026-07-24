import 'api_value_parser.dart';

class BlockedUrlModel {
  final String id;
  final String userId;
  final String url;
  final String? reason;
  final DateTime? blockedAt;

  BlockedUrlModel({
    required this.id,
    required this.userId,
    required this.url,
    this.reason,
    this.blockedAt,
  });

  factory BlockedUrlModel.fromJson(Map<String, dynamic> json) {
    return BlockedUrlModel(
      id: apiString(
        json['id'],
        fallback: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      userId: apiString(json['user_id']),
      url: apiString(json['url']),
      reason: apiNullableString(json['reason']),
      blockedAt: apiDateTime(json['blocked_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'url': url,
      'reason': reason,
      'blocked_at': blockedAt?.toIso8601String(),
    };
  }
}
