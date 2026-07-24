import 'api_value_parser.dart';

class UserModel {
  final String userId;
  final String username;
  final String email;
  final String? avatarUrl;
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
    this.avatarUrl,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
    this.blockedList = const [],
    this.isPremium = false,
    this.lifetimeScanCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final plan = apiString(json['plan'], fallback: 'free');
    return UserModel(
      userId: apiString(json['user_id'] ?? json['id']),
      username: apiString(json['username'] ?? json['full_name']),
      email: apiString(json['email']),
      avatarUrl: apiNullableString(json['avatar_url']),
      role: apiString(json['role'], fallback: 'user'),
      createdAt: apiDateTime(json['created_at']),
      updatedAt: apiDateTime(json['updated_at']),
      blockedList: apiStringList(json['blocked_list']),
      isPremium: apiBool(json['is_premium'], fallback: plan != 'free'),
      lifetimeScanCount: apiInt(json['lifetime_scan_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'blocked_list': blockedList,
      'is_premium': isPremium,
      'lifetime_scan_count': lifetimeScanCount,
    };
  }

  UserModel copyWith({
    String? userId,
    String? username,
    String? email,
    String? avatarUrl,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blockedList: blockedList ?? this.blockedList,
      isPremium: isPremium ?? this.isPremium,
      lifetimeScanCount: lifetimeScanCount ?? this.lifetimeScanCount,
    );
  }
}
