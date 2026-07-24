<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/HttpClient.php';
require dirname(__DIR__) . '/src/Mailer.php';
require dirname(__DIR__) . '/src/NotificationController.php';

// Configurable weights for Confidence Formula
define('CONFIDENCE_WEIGHT_COMMUNITY', 0.25);
define('CONFIDENCE_WEIGHT_VIRUSTOTAL', 0.30);
define('CONFIDENCE_WEIGHT_AI', 0.20);
define('CONFIDENCE_WEIGHT_BLACKLISTS', 0.10);
define('CONFIDENCE_WEIGHT_DOMAIN_AGE', 0.05);
define('CONFIDENCE_WEIGHT_REPORTER_TRUST', 0.10);

// Configurable severity weights for Priority calculation
const SEVERITY_WEIGHTS = [
    'phishing' => 25,
    'malware' => 25,
    'unsafe_download' => 20,
    'crypto_scam' => 20,
    'scam' => 15,
    'fake_login' => 15,
    'spam' => 5,
    'fake_banking' => 25,
    'investment_scam' => 20,
    'fake_shopping' => 15,
    'identity_theft' => 25,
    'other' => 10,
];

echo "URL Defender - Community Report Verification Worker started...\n";

while (true) {
    try {
        $db = Database::connection();
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

        // Fetch queued job
        $db->beginTransaction();
        $stmt = $db->prepare('SELECT * FROM report_jobs WHERE status = "queued" LIMIT 1 FOR UPDATE');
        $stmt->execute();
        $job = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$job) {
            $db->commit();
            sleep(2);
            continue;
        }

        // Lock report row
        $stmt = $db->prepare('SELECT * FROM community_reports WHERE id = ? FOR UPDATE');
        $stmt->execute([$job['report_id']]);
        $report = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$report) {
            $db->prepare('UPDATE report_jobs SET status = "failed" WHERE id = ?')->execute([$job['id']]);
            $db->commit();
            continue;
        }

        // Set status to processing
        $db->prepare('UPDATE report_jobs SET status = "processing", attempts = attempts + 1 WHERE id = ?')
            ->execute([$job['id']]);
        $db->commit();

        echo "Processing report ID: {$report['id']} for URL: {$report['url']}\n";

        // ─── 1. Community Voting score ───
        $stmt = $db->prepare('SELECT vote_type, SUM(vote_weight) as weight_sum FROM community_report_votes WHERE report_id = ? GROUP BY vote_type');
        $stmt->execute([$report['id']]);
        $votes = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $confirmWeight = 0.0;
        $safeWeight = 0.0;
        foreach ($votes as $v) {
            if ($v['vote_type'] === 'confirm_threat') {
                $confirmWeight = (double) $v['weight_sum'];
            } else {
                $safeWeight = (double) $v['weight_sum'];
            }
        }
        $totalWeight = $confirmWeight + $safeWeight;
        $communityRatio = $totalWeight > 0 ? ($confirmWeight / $totalWeight) : 0.5;

        // ─── 2. VirusTotal score ───
        // Check if there is an existing scan for this url hash
        $stmt = $db->prepare('SELECT id, verdict, risk_score, threat_category, scanned_at FROM scans WHERE normalized_url_hash = ? ORDER BY created_at DESC LIMIT 1');
        $stmt->execute([$report['normalized_url_hash']]);
        $scan = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$scan) {
            $scanId = uuid();
            $jobId = uuid();
            
            $db->beginTransaction();
            try {
                // Insert scan
                $stmt = $db->prepare("INSERT INTO scans (id, user_id, url, normalized_url, normalized_url_hash, hostname, verdict) VALUES (?, ?, ?, ?, ?, ?, 'pending')");
                $stmt->execute([
                    $scanId,
                    $report['reporter_id'],
                    $report['url'],
                    $report['url'],
                    $report['normalized_url_hash'],
                    parse_url($report['url'], PHP_URL_HOST) ?: $report['url'],
                ]);
                
                // Queue scan job
                $stmt = $db->prepare("INSERT INTO scan_jobs (id, scan_id, status) VALUES (?, ?, 'queued')");
                $stmt->execute([$jobId, $scanId]);
                
                // Defer report job
                $db->prepare('UPDATE report_jobs SET status = "queued" WHERE id = ?')->execute([$job['id']]);
                $db->commit();
            } catch (Throwable $e) {
                $db->rollBack();
                throw $e;
            }
            echo "No scan exists for URL: {$report['url']}. Created scan job and deferring report job.\n";
            sleep(2);
            continue;
        }

        if ($scan['verdict'] === 'pending') {
            $db->beginTransaction();
            try {
                $db->prepare('UPDATE report_jobs SET status = "queued" WHERE id = ?')->execute([$job['id']]);
                $db->commit();
            } catch (Throwable $e) {
                $db->rollBack();
                throw $e;
            }
            echo "Scan is still pending for URL: {$report['url']}. Deferring report job.\n";
            sleep(2);
            continue;
        }

        $vtDetections = 0;
        $aiRiskScore = 0;
        $blacklistHits = 0;
        $domainAgeDays = 365;

        if ($scan) {
            $aiRiskScore = (int) ($scan['risk_score'] ?? 0);
            
            // Check scan_results details
            $stmt = $db->prepare('SELECT * FROM scan_results WHERE scan_id = ? LIMIT 1');
            $stmt->execute([$scan['id']]);
            $details = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($details) {
                $blacklistHits = (int) ($details['blacklist_listed'] ?? 0);
                $domainAgeDays = (int) ($details['domain_age_days'] ?? 365);
            }
            
            // Detections ratio
            $stmt = $db->prepare('SELECT COUNT(*) FROM scan_engines WHERE scan_id = ? AND flagged = 1');
            $stmt->execute([$scan['id']]);
            $vtDetections = (int) $stmt->fetchColumn();
        }

        $vtRatio = min(1.0, $vtDetections / 10.0);
        $blacklistRatio = min(1.0, $blacklistHits / 5.0);
        
        // Domain age factor (newer domain = higher risk = lower safety factor)
        $domainAgeFactor = $domainAgeDays < 30 ? 1.0 : ($domainAgeDays < 365 ? 0.5 : 0.0);

        // ─── 3. Reporter trust score (Average trust score of reporting users) ───
        $stmt = $db->prepare('SELECT AVG(COALESCE(rr.trust_score, 50)) FROM community_report_votes crv LEFT JOIN reporter_reputation rr ON crv.user_id = rr.user_id WHERE crv.report_id = ? AND crv.vote_type = "confirm_threat"');
        $stmt->execute([$report['id']]);
        $avgReporterTrust = (double) ($stmt->fetchColumn() ?: 50.0);
        $reputationRatio = $avgReporterTrust / 100.0;

        // ─── 4. Modular Threat Intel Sources Aggregation ───
        // Configured for clean additions/subtractions without pipeline restructurings
        $intelSources = [
            'VirusTotal' => ['flagged' => $vtRatio > 0.5, 'weight' => CONFIDENCE_WEIGHT_VIRUSTOTAL],
            'AI' => ['flagged' => ($aiRiskScore / 100.0) > 0.5, 'weight' => CONFIDENCE_WEIGHT_AI],
            'Blacklists' => ['flagged' => $blacklistRatio > 0.5, 'weight' => CONFIDENCE_WEIGHT_BLACKLISTS],
            'GoogleSafeBrowsing' => ['flagged' => false, 'weight' => 0.0, 'stub' => true],
            'OpenPhish' => ['flagged' => false, 'weight' => 0.0, 'stub' => true],
            'PhishTank' => ['flagged' => false, 'weight' => 0.0, 'stub' => true],
            'URLHaus' => ['flagged' => false, 'weight' => 0.0, 'stub' => true],
            'SpamhausDBL' => ['flagged' => false, 'weight' => 0.0, 'stub' => true],
        ];

        // ─── 5. Calculate Confidence Score ───
        // Formula: Confidence = 25% Community + 30% VirusTotal + 20% URL Defender AI + 10% Blacklists + 5% Domain Age + 10% Reporter Trust
        $confidence = (CONFIDENCE_WEIGHT_COMMUNITY * $communityRatio) + 
                      (CONFIDENCE_WEIGHT_VIRUSTOTAL * $vtRatio) + 
                      (CONFIDENCE_WEIGHT_AI * ($aiRiskScore / 100.0)) + 
                      (CONFIDENCE_WEIGHT_BLACKLISTS * $blacklistRatio) + 
                      (CONFIDENCE_WEIGHT_DOMAIN_AGE * $domainAgeFactor) + 
                      (CONFIDENCE_WEIGHT_REPORTER_TRUST * $reputationRatio);
        
        $confidenceScore = (int) round($confidence * 100);

        // ─── 6. Calculate Priority Score ───
        // Formula: confidence_score + average reporter trust + (number of reports * 2.0) + threat_type severity weighting
        $reportsCount = (int) $report['report_count'];
        $severityWeight = SEVERITY_WEIGHTS[$report['threat_category']] ?? 10;
        $priorityScore = $confidenceScore + $avgReporterTrust + ($reportsCount * 2.0) + $severityWeight;

        // Update status thresholds
        $status = 'pending';
        if ($priorityScore >= 120) {
            $status = 'high_risk';
        } else if ($priorityScore >= 80) {
            $status = 'needs_review';
        }

        $db->beginTransaction();
        try {
            // Save verification results
            $db->prepare('INSERT INTO report_verification_results (report_id, confidence_score, computed_at) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE confidence_score = VALUES(confidence_score), computed_at = NOW()')
                ->execute([$report['id'], $confidenceScore]);

            // Update report
            $db->prepare('UPDATE community_reports SET priority_score = ?, verification_status = ? WHERE id = ?')
                ->execute([$priorityScore, $status, $report['id']]);

            // Set job to completed
            $db->prepare('UPDATE report_jobs SET status = "completed" WHERE id = ?')->execute([$job['id']]);

            // Trigger structured notifications for reporter and admins
            $notifier = new NotificationController($db);
            $notifier->notifyVerificationComplete($report['id'], $report['url'], $confidenceScore, $status);

            // Outgoing transactional email to system admin if high priority
            if ($status === 'high_risk') {
                $adminEmail = env('ADMIN_ALERT_EMAIL');
                if ($adminEmail !== null && $adminEmail !== '') {
                    $mailer = new Mailer();
                    $subject = 'High Priority Threat Report - Action Required';
                    $text = "A high priority community threat report was registered.\nURL: {$report['url']}\nCategory: {$report['threat_category']}\nConfidence Score: {$confidenceScore}%\nPriority Score: {$priorityScore}\n\nPlease review it in the admin queue.";
                    $html = <<<HTML
<!doctype html>
<html>
<body style="margin:0;padding:24px;background:#f8fafc;font-family:Arial,sans-serif;color:#111827">
  <div style="max-width:520px;margin:0 auto;padding:32px;background:#ffffff;border:1px solid #e5e7eb;border-radius:18px">
    <h1 style="margin:0 0 12px;font-size:24px;color:#ef4444">High Priority Threat Report</h1>
    <p style="margin:0 0 24px;color:#4b5563;line-height:1.6">The verification pipeline identified a high confidence threat report requiring administrative review.</p>
    <div style="padding:16px;background:#f3f4f6;border-radius:12px;margin-bottom:24px">
      <strong>URL:</strong> {$report['url']}<br/>
      <strong>Category:</strong> {$report['threat_category']}<br/>
      <strong>Confidence:</strong> {$confidenceScore}%<br/>
      <strong>Priority:</strong> {$priorityScore}
    </div>
    <a href="http://localhost:8080/dashboard" style="display:inline-block;padding:14px 22px;border-radius:12px;background:#ef4444;color:#ffffff;text-decoration:none;font-weight:700">Go to Review Queue</a>
  </div>
</body>
</html>
HTML;
                    try {
                        $mailer->send($adminEmail, $subject, $text, $html);
                    } catch (Throwable $e) {
                        error_log('Admin mail alert failed: ' . $e->getMessage());
                    }
                }
            }

            $db->commit();
            echo "Report ID: {$report['id']} processed successfully. Confidence: {$confidenceScore}%, Status: {$status}.\n";
        } catch (Throwable $transEx) {
            $db->rollBack();
            throw $transEx;
        }

    } catch (Throwable $e) {
        echo "Worker error: " . $e->getMessage() . "\n";
        sleep(5);
    }
    sleep(2);
}
