-- Community Threat Reports Migration
USE url_defender;

-- Reporter Reputation
CREATE TABLE IF NOT EXISTS reporter_reputation (
  user_id CHAR(36) NOT NULL,
  trust_score TINYINT UNSIGNED NOT NULL DEFAULT 10,
  approved_reports INT UNSIGNED NOT NULL DEFAULT 0,
  rejected_reports INT UNSIGNED NOT NULL DEFAULT 0,
  false_reports INT UNSIGNED NOT NULL DEFAULT 0,
  last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_rep_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Community Threat Reports
CREATE TABLE IF NOT EXISTS community_reports (
  id CHAR(36) NOT NULL,
  reporter_id CHAR(36) NOT NULL,
  url VARCHAR(2048) NOT NULL,
  normalized_url_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  threat_category ENUM('phishing', 'malware', 'scam', 'fake_login', 'crypto_scam', 'spam', 'unsafe_download') NOT NULL,
  description TEXT NOT NULL,
  screenshot_url VARCHAR(500) DEFAULT NULL,
  report_count INT UNSIGNED NOT NULL DEFAULT 1,
  last_reported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  verification_status ENUM('pending', 'high_risk', 'needs_review', 'duplicate', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  priority_score DOUBLE NOT NULL DEFAULT 0.0,
  approved_by CHAR(36) DEFAULT NULL,
  approved_at DATETIME DEFAULT NULL,
  merged_into CHAR(36) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rep_reporter_url (reporter_id, normalized_url_hash),
  KEY idx_rep_status_priority (verification_status, priority_score DESC),
  CONSTRAINT fk_rep_reporter FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_rep_approved FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Community Report Votes
CREATE TABLE IF NOT EXISTS community_report_votes (
  id CHAR(36) NOT NULL,
  report_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  vote_type ENUM('confirm_threat', 'looks_safe') NOT NULL,
  vote_weight DOUBLE NOT NULL DEFAULT 0.1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_votes_user_report (report_id, user_id),
  CONSTRAINT fk_votes_report FOREIGN KEY (report_id) REFERENCES community_reports(id) ON DELETE CASCADE,
  CONSTRAINT fk_votes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Verification Pipeline Results
CREATE TABLE IF NOT EXISTS report_verification_results (
  report_id CHAR(36) NOT NULL,
  confidence_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  computed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (report_id),
  CONSTRAINT fk_ver_report FOREIGN KEY (report_id) REFERENCES community_reports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Verified Community Intelligence (Fast Read Layer)
CREATE TABLE IF NOT EXISTS verified_community_intelligence (
  url_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  url VARCHAR(2048) NOT NULL,
  threat_category ENUM('phishing', 'malware', 'scam', 'fake_login', 'crypto_scam', 'spam', 'unsafe_download') NOT NULL,
  reporter_count INT UNSIGNED NOT NULL DEFAULT 1,
  confidence_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  approved_at DATETIME NOT NULL,
  last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (url_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Blocked Reporters
CREATE TABLE IF NOT EXISTS blocked_reporters (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  reason VARCHAR(255) NOT NULL,
  blocked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_blocked_user (user_id),
  CONSTRAINT fk_blocked_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Verification Queue Jobs
CREATE TABLE IF NOT EXISTS report_jobs (
  id CHAR(36) NOT NULL,
  report_id CHAR(36) NOT NULL,
  status ENUM('queued', 'processing', 'completed', 'failed') NOT NULL DEFAULT 'queued',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_jobs_report FOREIGN KEY (report_id) REFERENCES community_reports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
