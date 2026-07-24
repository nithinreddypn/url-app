-- Community Threat Reports Refinements Migration
USE url_defender;

-- Update default trust_score in reporter_reputation to 50
ALTER TABLE reporter_reputation ALTER COLUMN trust_score SET DEFAULT 50;

-- Create admin_audit_log table
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id CHAR(36) NOT NULL,
  admin_id CHAR(36) NOT NULL,
  action ENUM('approve', 'reject', 'merge', 'block_reporter') NOT NULL,
  target_id VARCHAR(36) NOT NULL,
  notes TEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_audit_admin FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
