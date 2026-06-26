class UserModel {
  final String userId;
  final String username;
  final String email;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> blockedList;
  final bool isPremium;
  final int lifetimeScanCount;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
    this.blockedList = const [],
    this.isPremium = false,
    this.lifetimeScanCount = 0,
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null
          ? _parseUtc(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? _parseUtc(json['updated_at'] as String)
          : null,
      blockedList: json['blocked_list'] != null
          ? List<String>.from(json['blocked_list'] as List)
          : const [],
      isPremium: json['is_premium'] as bool? ?? false,
      lifetimeScanCount: json['lifetime_scan_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'role': role,
      'blocked_list': blockedList,
      'is_premium': isPremium,
      'lifetime_scan_count': lifetimeScanCount,
    };
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? blockedList,
    bool? isPremium,
    int? lifetimeScanCount,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blockedList: blockedList ?? this.blockedList,
      isPremium: isPremium ?? this.isPremium,
      lifetimeScanCount: lifetimeScanCount ?? this.lifetimeScanCount,
    );
  }
}
