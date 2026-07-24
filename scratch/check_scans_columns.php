<?php
require 'backend/src/Support.php';
loadEnv('backend/.env');
require 'backend/src/Database.php';

try {
    $db = Database::connection();
    $stmt = $db->query('DESCRIBE scans');
    print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
