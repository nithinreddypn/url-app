-- Operational tables needed to process scans and payment webhooks safely.
USE url_defender;

CREATE TABLE scan_jobs (
  id CHAR(36) NOT NULL,
  scan_id CHAR(36) NOT NULL,
  status ENUM('queued','processing','completed','failed') NOT NULL DEFAULT 'queued',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  available_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  locked_at DATETIME DEFAULT NULL,
  locked_by VARCHAR(100) DEFAULT NULL,
  last_error VARCHAR(500) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_scan_jobs_scan (scan_id),
  KEY idx_scan_jobs_claim (status, available_at),
  CONSTRAINT fk_scan_jobs_scan FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE webhook_events (
  id CHAR(36) NOT NULL,
  provider ENUM('razorpay') NOT NULL,
  event_hash CHAR(64) NOT NULL,
  event_type VARCHAR(120) NOT NULL,
  payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
  processed_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_webhook_event_hash (provider, event_hash),
  KEY idx_webhook_pending (processed_at, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
