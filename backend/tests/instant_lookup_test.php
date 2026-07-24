<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/ScanController.php';

function expect(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$first = normalizeUrlInput(' https://Example.COM/ ');
$second = normalizeUrlInput('example.com');
expect($first['normalized_url'] === 'example.com', 'URL normalization returned an unexpected key.');
expect($first['normalized_url_hash'] === $second['normalized_url_hash'], 'Equivalent URLs produced different hashes.');

$db = Database::connection();
$sample = $db->query(
    "SELECT id, user_id, url FROM scans
     WHERE verdict IN ('safe','suspicious','dangerous')
     ORDER BY COALESCE(scanned_at, created_at) DESC LIMIT 1"
)->fetch();
expect(is_array($sample), 'A completed scan is required for the database lookup test.');

$controller = new ScanController($db);
$found = $controller->lookup(['id' => $sample['user_id']], ['url' => $sample['url']]);
expect($found['exists'] === true, 'Completed scan was not found by normalized lookup.');
expect(isset($found['analysis']['source']), 'Sanitized analysis source is missing.');
expect(!isset($found['analysis']['user_id']), 'Lookup exposed another user identifier.');
expect(!isset($found['analysis']['username']), 'Lookup exposed another username.');

$missing = $controller->lookup(
    ['id' => $sample['user_id']],
    ['url' => 'https://not-cached-' . bin2hex(random_bytes(8)) . '.invalid'],
);
expect($missing['exists'] === false, 'Unknown URL unexpectedly returned cached intelligence.');

$indexes = $db->query(
    "SHOW INDEX FROM scans WHERE Key_name IN ('idx_scans_normalized_cache', 'idx_scans_user_normalized')"
)->fetchAll();
$indexNames = array_unique(array_column($indexes, 'Key_name'));
expect(in_array('idx_scans_normalized_cache', $indexNames, true), 'Global lookup index is missing.');
expect(in_array('idx_scans_user_normalized', $indexNames, true), 'Personal history lookup index is missing.');

echo "Instant scans-table lookup tests passed.\n";
