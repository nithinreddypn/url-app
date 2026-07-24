-- URL Defender backend schema (MySQL 8.0+ / InnoDB / utf8mb4)
CREATE DATABASE IF NOT EXISTS url_defender CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE url_defender;

CREATE TABLE users (
  id CHAR(36) NOT NULL, email VARCHAR(191) NOT NULL, password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(120) NOT NULL, avatar_url VARCHAR(500) DEFAULT NULL,
  plan ENUM('free','team','enterprise') NOT NULL DEFAULT 'free', email_verified_at DATETIME DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1, last_login_at DATETIME DEFAULT NULL, deleted_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_users_email (email), KEY idx_users_plan (plan), KEY idx_users_deleted_at (deleted_at),
  KEY idx_users_active_plan (is_active, plan), KEY idx_users_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_roles (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL,
  role ENUM('admin','moderator','user','billing') NOT NULL DEFAULT 'user', created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_user_role (user_id, role), KEY idx_user_roles_role (role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE email_verifications (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, code_hash VARCHAR(255) NOT NULL, expires_at DATETIME NOT NULL,
  consumed_at DATETIME DEFAULT NULL, attempts TINYINT UNSIGNED NOT NULL DEFAULT 0, verified_ip VARCHAR(45) DEFAULT NULL,
  verified_user_agent VARCHAR(255) DEFAULT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_ev_user_expires (user_id, expires_at), KEY idx_ev_expires_at (expires_at),
  CONSTRAINT fk_ev_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE password_resets (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, token_hash VARCHAR(255) NOT NULL, expires_at DATETIME NOT NULL,
  consumed_at DATETIME DEFAULT NULL, requested_ip VARCHAR(45) DEFAULT NULL, requested_user_agent VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_pr_token_hash (token_hash), KEY idx_pr_user (user_id), KEY idx_pr_expires_at (expires_at),
  CONSTRAINT fk_pr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE auth_sessions (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, token_hash VARCHAR(255) NOT NULL, ip_address VARCHAR(45) DEFAULT NULL,
  user_agent VARCHAR(255) DEFAULT NULL, expires_at DATETIME NOT NULL, revoked_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_as_token_hash (token_hash), KEY idx_as_user_expires (user_id, expires_at),
  KEY idx_as_user_active (user_id, revoked_at, expires_at),
  CONSTRAINT fk_as_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE login_attempts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, email VARCHAR(191) NOT NULL, user_id CHAR(36) DEFAULT NULL,
  ip_address VARCHAR(45) DEFAULT NULL, user_agent VARCHAR(255) DEFAULT NULL, success TINYINT(1) NOT NULL DEFAULT 0,
  failure_reason VARCHAR(120) DEFAULT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_la_email_created (email, created_at), KEY idx_la_ip_created (ip_address, created_at),
  KEY idx_la_user_created (user_id, created_at), KEY idx_la_success (success, created_at),
  CONSTRAINT fk_la_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE scans (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, url VARCHAR(2048) NOT NULL,
  normalized_url VARCHAR(2048) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  normalized_url_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  hostname VARCHAR(255) NOT NULL,
  verdict ENUM('safe','suspicious','dangerous','pending','error') NOT NULL DEFAULT 'pending',
  risk_score TINYINT UNSIGNED NOT NULL DEFAULT 0, threat_category VARCHAR(120) DEFAULT NULL, duration_ms INT UNSIGNED DEFAULT NULL,
  scanned_at DATETIME DEFAULT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_scans_user_created (user_id, created_at DESC), KEY idx_scans_hostname (hostname),
  KEY idx_scans_verdict (verdict), KEY idx_scans_user_verdict (user_id, verdict, created_at DESC),
  KEY idx_scans_hostname_verdict (hostname, verdict),
  KEY idx_scans_normalized_cache (normalized_url_hash, verdict, scanned_at),
  KEY idx_scans_user_normalized (user_id, normalized_url_hash, scanned_at),
  CONSTRAINT fk_scans_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE scan_results (
  scan_id CHAR(36) NOT NULL, ip_address VARCHAR(45) DEFAULT NULL,
  ssl_status ENUM('valid','expired','invalid','none') NOT NULL DEFAULT 'none', ssl_issuer VARCHAR(255) DEFAULT NULL,
  ssl_valid_from DATETIME DEFAULT NULL, ssl_expires_at DATETIME DEFAULT NULL, domain_age_days INT UNSIGNED NOT NULL DEFAULT 0,
  blacklist_listed SMALLINT UNSIGNED NOT NULL DEFAULT 0, blacklist_total SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  redirect_chain LONGTEXT DEFAULT NULL CHECK (redirect_chain IS NULL OR JSON_VALID(redirect_chain)),
  headers LONGTEXT DEFAULT NULL CHECK (headers IS NULL OR JSON_VALID(headers)),
  recommendations LONGTEXT DEFAULT NULL CHECK (recommendations IS NULL OR JSON_VALID(recommendations)),
  submitted_at DATETIME DEFAULT NULL, analyzed_at DATETIME DEFAULT NULL, completed_at DATETIME DEFAULT NULL,
  raw_response LONGTEXT DEFAULT NULL CHECK (raw_response IS NULL OR JSON_VALID(raw_response)),
  PRIMARY KEY (scan_id), CONSTRAINT fk_sr_scan FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE scan_engines (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, scan_id CHAR(36) NOT NULL, engine_name VARCHAR(80) NOT NULL,
  flagged TINYINT(1) NOT NULL DEFAULT 0, label VARCHAR(120) NOT NULL,
  PRIMARY KEY (id), KEY idx_se_scan (scan_id), KEY idx_se_scan_flagged (scan_id, flagged),
  KEY idx_se_engine_flagged (engine_name, flagged),
  CONSTRAINT fk_se_scan FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, scan_id CHAR(36) DEFAULT NULL,
  type ENUM('scan_complete','threat_detected','system','billing','security') NOT NULL,
  title VARCHAR(200) NOT NULL, message TEXT NOT NULL, severity ENUM('info','warning','critical') NOT NULL DEFAULT 'info',
  read_at DATETIME DEFAULT NULL, dismissed TINYINT(1) NOT NULL DEFAULT 0, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_notif_user_created (user_id, created_at DESC), KEY idx_notif_unread (user_id, read_at),
  KEY idx_notif_user_dismissed (user_id, dismissed, created_at DESC), KEY idx_notif_scan (scan_id),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_scan FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subscriptions (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, plan ENUM('free','team','enterprise') NOT NULL,
  status ENUM('active','past_due','canceled','expired','trialing') NOT NULL DEFAULT 'active',
  razorpay_sub_id VARCHAR(120) DEFAULT NULL, current_period_start DATETIME DEFAULT NULL, current_period_end DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_sub_razorpay_id (razorpay_sub_id), KEY idx_sub_user (user_id),
  KEY idx_sub_user_status (user_id, status), KEY idx_sub_period_end (current_period_end),
  CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payments (
  id CHAR(36) NOT NULL, user_id CHAR(36) NOT NULL, subscription_id CHAR(36) DEFAULT NULL,
  razorpay_order_id VARCHAR(64) NOT NULL, razorpay_payment_id VARCHAR(64) DEFAULT NULL, razorpay_signature VARCHAR(255) DEFAULT NULL,
  receipt VARCHAR(64) DEFAULT NULL, amount_paise INT UNSIGNED NOT NULL, currency CHAR(3) NOT NULL DEFAULT 'INR',
  method ENUM('upi','card','netbanking','wallet','emi') DEFAULT NULL,
  status ENUM('created','authorized','captured','failed','refunded','partially_refunded') NOT NULL DEFAULT 'created',
  failure_reason VARCHAR(255) DEFAULT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_pay_order (razorpay_order_id), UNIQUE KEY uq_pay_payment (razorpay_payment_id),
  UNIQUE KEY uq_pay_receipt (receipt), KEY idx_pay_user_created (user_id, created_at DESC),
  KEY idx_pay_user_status (user_id, status), KEY idx_pay_subscription (subscription_id), KEY idx_pay_status_created (status, created_at),
  CONSTRAINT fk_pay_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_pay_sub FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usage_monthly (
  user_id CHAR(36) NOT NULL, period CHAR(7) NOT NULL, scans_used INT UNSIGNED NOT NULL DEFAULT 0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, period), KEY idx_usage_period (period),
  CONSTRAINT fk_usage_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, user_id CHAR(36) DEFAULT NULL, action VARCHAR(80) NOT NULL,
  ip_address VARCHAR(45) DEFAULT NULL, user_agent VARCHAR(255) DEFAULT NULL,
  metadata LONGTEXT DEFAULT NULL CHECK (metadata IS NULL OR JSON_VALID(metadata)),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_audit_user_created (user_id, created_at DESC),
  KEY idx_audit_action_created (action, created_at DESC), KEY idx_audit_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Least-privilege development account; replace the password before use.
-- CREATE USER 'url_defender_app'@'localhost' IDENTIFIED BY 'change_me';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON url_defender.* TO 'url_defender_app'@'localhost';
