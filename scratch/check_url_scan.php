<?php
require 'backend/src/Support.php';
loadEnv('backend/.env');
require 'backend/src/Database.php';

try {
    $db = Database::connection();
    $url = 'www.marketingbyinternet.com/mo/e56508df639f6ce7d55c81ee3fcd5ba8';
    $normalized = normalizeUrlInput($url);
    $hash = $normalized['normalized_url_hash'];

    echo "Normalized Hash: $hash\n";

    // Query scan
    $stmt = $db->prepare('SELECT id, verdict, risk_score, threat_category FROM scans WHERE normalized_url_hash = ?');
    $stmt->execute([$hash]);
    $scans = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "--- SCANS ---\n";
    print_r($scans);

    if (!empty($scans)) {
        $scanId = $scans[0]['id'];
        // Query scan_results
        $stmt = $db->prepare('SELECT scan_id, ssl_status, domain_age_days, blacklist_listed, blacklist_total FROM scan_results WHERE scan_id = ?');
        $stmt->execute([$scanId]);
        echo "--- SCAN RESULTS ---\n";
        print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
    }
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
