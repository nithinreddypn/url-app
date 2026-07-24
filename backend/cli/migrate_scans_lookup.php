<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';

$db = Database::connection();
$requiredColumns = ['normalized_url', 'normalized_url_hash'];
$columns = $db->query(
    "SHOW COLUMNS FROM scans WHERE Field IN ('normalized_url', 'normalized_url_hash')"
)->fetchAll();
$presentColumns = array_column($columns, 'Field');
foreach ($requiredColumns as $column) {
    if (!in_array($column, $presentColumns, true)) {
        fwrite(STDERR, "Missing scans.{$column}. Import the current base schema before enabling instant lookup.\n");
        exit(1);
    }
}

$indexes = $db->query(
    "SHOW INDEX FROM scans WHERE Key_name IN ('idx_scans_normalized_cache', 'idx_scans_user_normalized')"
)->fetchAll();
$presentIndexes = array_values(array_unique(array_column($indexes, 'Key_name')));

if (!in_array('idx_scans_normalized_cache', $presentIndexes, true)) {
    $db->exec(
        'CREATE INDEX idx_scans_normalized_cache ON scans (normalized_url_hash, verdict, scanned_at)'
    );
}
if (!in_array('idx_scans_user_normalized', $presentIndexes, true)) {
    $db->exec(
        'CREATE INDEX idx_scans_user_normalized ON scans (user_id, normalized_url_hash, scanned_at)'
    );
}

echo "Instant lookup indexes are ready on the existing scans table.\n";
