<?php
require 'backend/src/Support.php';
loadEnv('backend/.env');
require 'backend/src/Database.php';

try {
    $db = Database::connection();
    $userId = 'aa1f12ff-bb4e-4770-b55a-62f783479639';
    
    // Select before
    $stmt = $db->prepare('SELECT id, title, dismissed FROM notifications WHERE user_id = ? AND type = "community_report"');
    $stmt->execute([$userId]);
    echo "Before clean:\n";
    print_r($stmt->fetchAll(PDO::FETCH_ASSOC));

    $sql = '
        UPDATE notifications n1
        INNER JOIN (
            SELECT related_report_id, MAX(created_at) as max_created
            FROM notifications
            WHERE user_id = ? AND type = "community_report" AND related_report_id IS NOT NULL AND dismissed = 0
            GROUP BY related_report_id
            HAVING COUNT(*) > 1
        ) n2 ON n1.related_report_id = n2.related_report_id
        SET n1.dismissed = 1
        WHERE n1.user_id = ? AND n1.type = "community_report" AND n1.created_at < n2.max_created AND n1.dismissed = 0
    ';
    $stmt = $db->prepare($sql);
    $stmt->execute([$userId, $userId]);
    echo "\nRows affected: " . $stmt->rowCount() . "\n";

    // Select after
    $stmt = $db->prepare('SELECT id, title, dismissed FROM notifications WHERE user_id = ? AND type = "community_report"');
    $stmt->execute([$userId]);
    echo "\nAfter clean:\n";
    print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
