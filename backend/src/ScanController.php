<?php
declare(strict_types=1);

final class ScanController
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function list(array $user): array
    {
        $limit = min(max((int) ($_GET['limit'] ?? 20), 1), 100);
        $verdict = $_GET['verdict'] ?? null;
        $sql = 'SELECT s.id, s.url, s.hostname, s.verdict, s.risk_score, s.threat_category, s.duration_ms, s.scanned_at, s.created_at, s.normalized_url_hash,
                       r.blacklist_listed, r.ssl_status, r.redirect_chain
                FROM scans s
                LEFT JOIN scan_results r ON r.scan_id = s.id
                WHERE s.user_id = ?';
        $parameters = [$user['id']];
        if (is_string($verdict) && in_array($verdict, ['safe', 'suspicious', 'dangerous', 'pending', 'error'], true)) {
            $sql .= ' AND s.verdict = ?';
            $parameters[] = $verdict;
        }
        $sql .= ' ORDER BY s.created_at DESC LIMIT ' . $limit;
        $stmt = $this->db->prepare($sql);
        $stmt->execute($parameters);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $items = [];
        foreach ($rows as $row) {
            $vtFlags = (int) ($row['blacklist_listed'] ?? 0);
            
            // Heuristic hits calculation
            $heuristicHits = 0;
            if ($row['ssl_status'] === 'expired' || $row['ssl_status'] === 'invalid') {
                $heuristicHits += 1;
            }
            $redirects = json_decode((string) ($row['redirect_chain'] ?? '[]'), true);
            if (is_array($redirects) && count($redirects) > 2) {
                $heuristicHits += 1;
            }

            // Count community reports
            $crStmt = $this->db->prepare('SELECT COUNT(*) FROM community_reports WHERE normalized_url_hash = ?');
            $crStmt->execute([$row['normalized_url_hash']]);
            $commCount = (int) $crStmt->fetchColumn();

            $row['virus_total_flags'] = $vtFlags;
            $row['heuristic_hits'] = $heuristicHits;
            $row['community_reports'] = $commCount;

            // Maintain result nested block for compatibility
            $row['result'] = [
                'blacklist_listed' => $vtFlags,
                'blacklist_total' => 0,
                'heuristic_hits' => $heuristicHits,
            ];

            unset($row['blacklist_listed'], $row['ssl_status'], $row['redirect_chain']);
            $items[] = $row;
        }
        return ['items' => $items];
    }

    public function lookup(array $user, array $input): array
    {
        $normalized = normalizeUrlInput((string) ($input['url'] ?? ''));
        $analysis = $this->findCachedAnalysis($normalized['normalized_url_hash']);
        if (!$analysis) {
            return [
                'success' => true,
                'exists' => false,
                'normalized_url' => $normalized['normalized_url'],
            ];
        }

        $history = $this->db->prepare(
            "SELECT id, COALESCE(scanned_at, created_at) AS last_scanned
             FROM scans
             WHERE user_id = ? AND normalized_url_hash = ? AND verdict IN ('safe','suspicious','dangerous')
             ORDER BY COALESCE(scanned_at, created_at) DESC LIMIT 1"
        );
        $history->execute([$user['id'], $normalized['normalized_url_hash']]);
        $ownScan = $history->fetch() ?: null;

        return [
            'success' => true,
            'exists' => true,
            'source' => 'database',
            'analysis' => $this->publicAnalysis($analysis, $normalized['normalized_url']),
            'already_in_history' => $ownScan !== null,
            'last_scanned' => $ownScan['last_scanned'] ?? null,
            'scan_id' => $ownScan['id'] ?? null,
        ];
    }

    public function create(array $user, array $input): array
    {
        $normalized = normalizeUrlInput((string) ($input['url'] ?? ''));

        $this->db->beginTransaction();
        try {
            $period = gmdate('Y-m');
            $this->db->prepare('INSERT INTO usage_monthly (user_id, period, scans_used) VALUES (?, ?, 0) ON DUPLICATE KEY UPDATE scans_used = scans_used')
                ->execute([$user['id'], $period]);
            $usage = $this->db->prepare('SELECT scans_used FROM usage_monthly WHERE user_id = ? AND period = ? FOR UPDATE');
            $usage->execute([$user['id'], $period]);
            $used = (int) $usage->fetchColumn();
            if ($user['plan'] === 'free' && $used >= 50) {
                throw new HttpException(429, 'Monthly scan limit reached. Upgrade your plan to continue.');
            }

            $scanId = uuid();
            $cached = $this->findCachedAnalysis($normalized['normalized_url_hash']);
            if ($cached) {
                $this->db->prepare(
                    'INSERT INTO scans (id, user_id, url, normalized_url, normalized_url_hash, hostname, verdict, risk_score, threat_category, duration_ms, scanned_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, UTC_TIMESTAMP())'
                )->execute([
                    $scanId,
                    $user['id'],
                    $normalized['url'],
                    $normalized['normalized_url'],
                    $normalized['normalized_url_hash'],
                    $normalized['hostname'],
                    $cached['verdict'],
                    $cached['risk_score'],
                    $cached['threat_category'],
                ]);
                $this->copyAnalysisRows($cached['id'], $scanId);
                $this->createNotification($user['id'], $scanId, $normalized['hostname'], $cached['verdict']);
                $action = 'scan.cache_reused';
            } else {
                $this->db->prepare(
                    "INSERT INTO scans (id, user_id, url, normalized_url, normalized_url_hash, hostname, verdict)
                     VALUES (?, ?, ?, ?, ?, ?, 'pending')"
                )->execute([
                    $scanId,
                    $user['id'],
                    $normalized['url'],
                    $normalized['normalized_url'],
                    $normalized['normalized_url_hash'],
                    $normalized['hostname'],
                ]);
                $jobId = uuid();
                $this->db->prepare("INSERT INTO scan_jobs (id, scan_id, status) VALUES (?, ?, 'queued')")
                    ->execute([$jobId, $scanId]);
                $action = 'scan.requested';
                
                // Commit transaction early to make rows visible to the worker, then run inline!
                $this->db->commit();
                try {
                    require_once __DIR__ . '/ScanWorker.php';
                    $worker = new ScanWorker($this->db);
                    $worker->processJobById($jobId, 'inline-api');
                } catch (Throwable $e) {
                    // Ignore inline worker failures
                }
                $this->db->beginTransaction();
            }

            $this->db->prepare('UPDATE usage_monthly SET scans_used = scans_used + 1 WHERE user_id = ? AND period = ?')
                ->execute([$user['id'], $period]);
            $this->audit($user['id'], $action, ['scan_id' => $scanId, 'hostname' => $normalized['hostname']]);
            $this->db->commit();

            $result = $this->detail($user, $scanId);
            $result['cached'] = $cached !== false;
            $result['source'] = $cached ? 'database' : 'provider_queue';
            return $result;
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function detail(array $user, string $scanId): array
    {
        // If the scan is still pending, run the worker inline to process it
        $check = $this->db->prepare('SELECT verdict FROM scans WHERE id = ? AND user_id = ? LIMIT 1');
        $check->execute([$scanId, $user['id']]);
        $verdict = $check->fetchColumn();

        if ($verdict === 'pending') {
            $jobStmt = $this->db->prepare("SELECT id FROM scan_jobs WHERE scan_id = ? AND status IN ('queued', 'processing') LIMIT 1");
            $jobStmt->execute([$scanId]);
            $jobId = $jobStmt->fetchColumn();
            if ($jobId) {
                try {
                    require_once __DIR__ . '/ScanWorker.php';
                    $worker = new ScanWorker($this->db);
                    $worker->processJobById($jobId, 'inline-detail-api');
                } catch (Throwable $e) {
                    // Ignore inline worker failures
                }
            }
        }

        $scan = $this->db->prepare('SELECT id, url, hostname, verdict, risk_score, threat_category, duration_ms, scanned_at, created_at, normalized_url_hash FROM scans WHERE id = ? AND user_id = ? LIMIT 1');
        $scan->execute([$scanId, $user['id']]);
        $item = $scan->fetch();
        if (!$item) {
            throw new HttpException(404, 'Scan not found.');
        }
        $result = $this->db->prepare('SELECT * FROM scan_results WHERE scan_id = ?');
        $result->execute([$scanId]);
        $resRow = $result->fetch() ?: null;

        $engines = $this->db->prepare('SELECT engine_name, flagged, label FROM scan_engines WHERE scan_id = ? ORDER BY flagged DESC, engine_name ASC');
        $engines->execute([$scanId]);

        $item['result'] = $resRow;
        $item['engines'] = $engines->fetchAll();

        // Calculate and add root metrics
        $vtFlags = 0;
        $heuristicHits = 0;
        if ($resRow) {
            $vtFlags = (int) ($resRow['blacklist_listed'] ?? 0);
            if ($resRow['ssl_status'] === 'expired' || $resRow['ssl_status'] === 'invalid') {
                $heuristicHits += 1;
            }
            $redirects = json_decode((string) ($resRow['redirect_chain'] ?? '[]'), true);
            if (is_array($redirects) && count($redirects) > 2) {
                $heuristicHits += 1;
            }
        }
        
        // Count community reports
        $crStmt = $this->db->prepare('SELECT COUNT(*) FROM community_reports WHERE normalized_url_hash = ?');
        $crStmt->execute([$item['normalized_url_hash']]);
        $commCount = (int) $crStmt->fetchColumn();

        $item['virus_total_flags'] = $vtFlags;
        $item['heuristic_hits'] = $heuristicHits;
        $item['community_reports'] = $commCount;

        return $item;
    }

    public function delete(array $user, string $scanId): array
    {
        $stmt = $this->db->prepare('DELETE FROM scans WHERE id = ? AND user_id = ?');
        $stmt->execute([$scanId, $user['id']]);
        if ($stmt->rowCount() === 0) {
            throw new HttpException(404, 'Scan not found.');
        }

        $this->audit($user['id'], 'scan.deleted', ['scan_id' => $scanId]);
        return ['message' => 'Scan deleted.'];
    }

    public function usage(array $user): array
    {
        $period = gmdate('Y-m');
        $stmt = $this->db->prepare('SELECT scans_used FROM usage_monthly WHERE user_id = ? AND period = ?');
        $stmt->execute([$user['id'], $period]);
        $used = (int) ($stmt->fetchColumn() ?: 0);
        $limit = $user['plan'] === 'free' ? 50 : null;
        return ['period' => $period, 'scans_used' => $used, 'scan_limit' => $limit, 'scans_remaining' => $limit === null ? null : max(0, $limit - $used)];
    }

    private function findCachedAnalysis(string $hash): array|false
    {
        $stmt = $this->db->prepare(
            "SELECT s.id, s.url, s.verdict, s.risk_score, s.threat_category, s.scanned_at,
                    r.ssl_status, r.redirect_chain, r.blacklist_listed, r.blacklist_total
             FROM scans s
             LEFT JOIN scan_results r ON r.scan_id = s.id
             WHERE s.normalized_url_hash = ? AND s.verdict IN ('safe','suspicious','dangerous')
             ORDER BY COALESCE(s.scanned_at, s.created_at) DESC LIMIT 1"
        );
        $stmt->execute([$hash]);
        return $stmt->fetch();
    }

    private function publicAnalysis(array $row, string $normalizedUrl): array
    {
        $redirects = json_decode((string) ($row['redirect_chain'] ?? '[]'), true);
        return [
            'url' => $normalizedUrl,
            'status' => $row['verdict'],
            'risk_score' => (int) $row['risk_score'],
            'category' => $row['threat_category'] ?: ucfirst((string) $row['verdict']),
            'threat_type' => $row['threat_category'],
            'ssl_status' => $row['ssl_status'] ?? 'none',
            'redirect_count' => is_array($redirects) ? count($redirects) : 0,
            'vt_score' => [
                'flagged' => (int) ($row['blacklist_listed'] ?? 0),
                'total' => (int) ($row['blacklist_total'] ?? 0),
            ],
            'source' => 'URL Defender Threat Intelligence',
        ];
    }

    private function copyAnalysisRows(string $sourceScanId, string $targetScanId): void
    {
        $this->db->prepare(
            'INSERT INTO scan_results (scan_id, ip_address, ssl_status, ssl_issuer, ssl_valid_from, ssl_expires_at, domain_age_days, blacklist_listed, blacklist_total, redirect_chain, headers, recommendations, submitted_at, analyzed_at, completed_at, raw_response)
             SELECT ?, ip_address, ssl_status, ssl_issuer, ssl_valid_from, ssl_expires_at, domain_age_days, blacklist_listed, blacklist_total, redirect_chain, headers, recommendations, submitted_at, analyzed_at, UTC_TIMESTAMP(), raw_response
             FROM scan_results WHERE scan_id = ?'
        )->execute([$targetScanId, $sourceScanId]);
        $this->db->prepare(
            'INSERT INTO scan_engines (scan_id, engine_name, flagged, label)
             SELECT ?, engine_name, flagged, label FROM scan_engines WHERE scan_id = ?'
        )->execute([$targetScanId, $sourceScanId]);
    }

    private function createNotification(string $userId, string $scanId, string $hostname, string $verdict): void
    {
        $type = $verdict === 'safe' ? 'scan_complete' : 'threat_detected';
        $severity = $verdict === 'dangerous' ? 'critical' : ($verdict === 'suspicious' ? 'warning' : 'info');
        $title = $verdict === 'dangerous' ? 'Threat detected' : ($verdict === 'suspicious' ? 'Suspicious URL detected' : 'Scan completed');
        $message = $verdict === 'safe' ? "Scan completed for {$hostname}." : "Potential threat detected for {$hostname}.";
        $this->db->prepare('INSERT INTO notifications (id, user_id, scan_id, type, title, message, severity) VALUES (?, ?, ?, ?, ?, ?, ?)')
            ->execute([uuid(), $userId, $scanId, $type, $title, $message, $severity]);
    }

    private function audit(string $userId, string $action, array $metadata): void
    {
        $this->db->prepare('INSERT INTO audit_log (user_id, action, ip_address, user_agent, metadata) VALUES (?, ?, ?, ?, ?)')
            ->execute([$userId, $action, clientIp(), userAgent(), json_encode($metadata)]);
    }
}
