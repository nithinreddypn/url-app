<?php
require 'backend/src/Support.php';
loadEnv('backend/.env');
require 'backend/src/Database.php';

try {
    $db = Database::connection();
    $stmt = $db->query('SELECT * FROM notifications ORDER BY created_at DESC');
    $notifs = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "--- ALL NOTIFICATIONS ---\n";
    print_r($notifs);
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
