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

  static DateTime _parseUtc(String dateStr) {
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      final normalized = dateStr.replaceAll(' ', 'T');
      return DateTime.parse('${normalized}Z').toLocal();
    }
    return DateTime.parse(dateStr).toLocal();
  }

  factory BlockedUrlModel.fromJson(Map<String, dynamic> json) {
    return BlockedUrlModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      url: json['url'] as String,
      reason: json['reason'] as String?,
      blockedAt: json['blocked_at'] != null
          ? _parseUtc(json['blocked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'url': url,
      'reason': reason,
    };
  }
}
