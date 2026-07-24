-- Instant lookup uses the existing scans table only. No new table is created.
-- The normalized columns already exist in upgraded installations; this migration
-- adds the two lookup indexes only when they are missing. Import it while the
-- intended Hostinger/XAMPP database is selected; no database name is hardcoded.

SET @cache_index_exists = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'scans'
    AND index_name = 'idx_scans_normalized_cache'
);
SET @cache_index_sql = IF(
  @cache_index_exists = 0,
  'CREATE INDEX idx_scans_normalized_cache ON scans (normalized_url_hash, verdict, scanned_at)',
  'SELECT 1'
);
PREPARE cache_index_statement FROM @cache_index_sql;
EXECUTE cache_index_statement;
DEALLOCATE PREPARE cache_index_statement;

SET @history_index_exists = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'scans'
    AND index_name = 'idx_scans_user_normalized'
);
SET @history_index_sql = IF(
  @history_index_exists = 0,
  'CREATE INDEX idx_scans_user_normalized ON scans (user_id, normalized_url_hash, scanned_at)',
  'SELECT 1'
);
PREPARE history_index_statement FROM @history_index_sql;
EXECUTE history_index_statement;
DEALLOCATE PREPARE history_index_statement;
