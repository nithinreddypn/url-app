-- Community Notifications Enhancement Migration
USE url_defender;

-- Extend notifications type ENUM to support community notification categories
ALTER TABLE notifications
  MODIFY COLUMN type ENUM(
    'scan_complete','threat_detected','system','billing','security',
    'community_report','community_verified','community_rejected',
    'admin_review','threat_alert'
  ) NOT NULL DEFAULT 'system';

-- Add related_report_id for linking notifications to community reports
ALTER TABLE notifications
  ADD COLUMN related_report_id CHAR(36) DEFAULT NULL AFTER scan_id;

-- Add priority column
ALTER TABLE notifications
  ADD COLUMN priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'low' AFTER severity;

-- Add notification_category for grouping
ALTER TABLE notifications
  ADD COLUMN category VARCHAR(50) NOT NULL DEFAULT 'system' AFTER priority;

-- Index for community notification queries
ALTER TABLE notifications
  ADD INDEX idx_notif_type_created (type, created_at DESC),
  ADD INDEX idx_notif_report (related_report_id);

-- Add FK (optional, may fail if orphaned data exists)
-- ALTER TABLE notifications ADD CONSTRAINT fk_notif_report FOREIGN KEY (related_report_id) REFERENCES community_reports(id) ON DELETE SET NULL;
