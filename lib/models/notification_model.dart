import 'package:flutter/material.dart';
import 'api_value_parser.dart';

class NotificationModel {
  final String id;
  final String? scanId;
  final String? relatedReportId;
  final String type;
  final String title;
  final String message;
  final String severity;
  final String priority;
  final String category;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.scanId,
    this.relatedReportId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.priority = 'low',
    this.category = 'system',
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;
  bool get isCommunityType => type.startsWith('community_') || type == 'admin_review' || type == 'threat_alert';

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: apiString(json['id']),
      scanId: apiNullableString(json['scan_id']),
      relatedReportId: apiNullableString(json['related_report_id']),
      type: apiString(json['type']),
      title: apiString(json['title']),
      message: apiString(json['message']),
      severity: apiString(json['severity']),
      priority: apiString(json['priority'] ?? 'low'),
      category: apiString(json['category'] ?? 'system'),
      readAt: apiDateTime(json['read_at']),
      createdAt: apiDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  IconData get icon {
    switch (type) {
      case 'community_report':
        return Icons.flag_outlined;
      case 'community_verified':
        return Icons.verified_outlined;
      case 'community_rejected':
        return Icons.cancel_outlined;
      case 'admin_review':
        return Icons.admin_panel_settings_outlined;
      case 'threat_alert':
        return Icons.warning_amber_rounded;
      case 'threat_detected':
        return Icons.gpp_bad_outlined;
      case 'scan_complete':
        return Icons.check_circle_outline;
      case 'security':
        return Icons.shield_outlined;
      case 'billing':
        return Icons.payment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'community_verified':
      case 'threat_alert':
      case 'threat_detected':
        return const Color(0xFFEF4444);
      case 'community_report':
        return const Color(0xFFF59E0B);
      case 'community_rejected':
        return const Color(0xFF6B7280);
      case 'admin_review':
        return const Color(0xFFF97316);
      case 'scan_complete':
        return const Color(0xFF22C55E);
      case 'security':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'critical': return 'CRITICAL';
      case 'high': return 'HIGH';
      case 'medium': return 'MEDIUM';
      default: return 'LOW';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'critical': return const Color(0xFFEF4444);
      case 'high': return const Color(0xFFF97316);
      case 'medium': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6B7280);
    }
  }
}
