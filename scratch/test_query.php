<?php
require 'backend/src/Support.php';
loadEnv('backend/.env');
require 'backend/src/Database.php';

try {
    $db = Database::connection();
    $userId = 'aa1f12ff-bb4e-4770-b55a-62f783479639';
    $reportId = 'b4cf4fb2-03c6-4d06-8ce3-5e1b7f34409b';
    $type = 'community_report';

    $stmt = $db->prepare('SELECT id FROM notifications WHERE user_id = ? AND related_report_id = ? AND type = ? AND dismissed = 0 LIMIT 1');
    $stmt->execute([$userId, $reportId, $type]);
    $existingId = $stmt->fetchColumn();
    echo "Query Result for existing ID: " . var_export($existingId, true) . "\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
