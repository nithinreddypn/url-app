<?php
declare(strict_types=1);

final class ScanWorker
{
    public function __construct(private readonly PDO $db)
    {
    }

    /** Processes one queued scan. Run repeatedly from cli/scan_worker.php. */
    public function processJobById(string $jobId, string $workerId): bool
    {
        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare("SELECT * FROM scan_jobs WHERE id = ? FOR UPDATE");
            $stmt->execute([$jobId]);
            $job = $stmt->fetch();
            if (!$job) {
                $this->db->commit();
                return false;
            }
            $this->db->prepare("UPDATE scan_jobs SET status = 'processing', attempts = attempts + 1, locked_at = UTC_TIMESTAMP(), locked_by = ? WHERE id = ?")
                ->execute([$workerId, $job['id']]);
            $scan = $this->db->prepare('SELECT id, user_id, url, hostname, normalized_url_hash FROM scans WHERE id = ? FOR UPDATE');
            $scan->execute([$job['scan_id']]);
            $scan = $scan->fetch();
            $this->db->commit();
            if (!$scan) {
                throw new RuntimeException('Queued scan no longer exists.');
            }
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }

        $lockName = 'url-scan:' . substr((string) $scan['normalized_url_hash'], 0, 48);
        $lock = $this->db->prepare('SELECT GET_LOCK(?, 30)');
        $lock->execute([$lockName]);
        if ((int) $lock->fetchColumn() !== 1) {
            $this->deferFollower($job, 'Waiting for shared URL analysis.');
            return true;
        }

        $startedAt = microtime(true);
        try {
            $cached = $this->findCachedScan((string) $scan['normalized_url_hash'], (string) $scan['id']);
            if ($cached) {
                $this->completeFromCache($job, $scan, $cached);
                return true;
            }

            if ($this->hasEarlierActiveJob((string) $scan['normalized_url_hash'], (string) $job['id'], (string) $job['created_at'])) {
                $this->deferFollower($job, 'Waiting for shared URL analysis.');
                return true;
            }

            $report = $this->lookupVirusTotal($scan['url']);
            if ($report['state'] !== 'complete') {
                $this->retry($job, 'Provider analysis is not complete yet.');
                return true;
            }
            $this->complete($job, $scan, $report, (int) round((microtime(true) - $startedAt) * 1000));
        } catch (Throwable $error) {
            $this->retry($job, $error->getMessage());
        } finally {
            $release = $this->db->prepare('SELECT RELEASE_LOCK(?)');
            $release->execute([$lockName]);
        }
        return true;
    }

    public function processNext(string $workerId): bool
    {
        $this->db->beginTransaction();
        try {
            $job = $this->db->query("SELECT id FROM scan_jobs WHERE status = 'queued' AND available_at <= NOW() ORDER BY created_at ASC LIMIT 1 FOR UPDATE")->fetch();
            if (!$job) {
                $this->db->commit();
                return false;
            }
            $this->db->commit();
            return $this->processJobById($job['id'], $workerId);
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    private function findCachedScan(string $hash, string $excludeScanId): array|false
    {
        $stmt = $this->db->prepare(
            "SELECT id, verdict, risk_score, threat_category
             FROM scans
             WHERE normalized_url_hash = ? AND id <> ? AND verdict IN ('safe','suspicious','dangerous')
             ORDER BY COALESCE(scanned_at, created_at) DESC LIMIT 1"
        );
        $stmt->execute([$hash, $excludeScanId]);
        return $stmt->fetch();
    }

    private function hasEarlierActiveJob(string $hash, string $jobId, string $createdAt): bool
    {
        $stmt = $this->db->prepare(
            "SELECT 1
             FROM scan_jobs j
             INNER JOIN scans s ON s.id = j.scan_id
             WHERE s.normalized_url_hash = ?
               AND s.verdict = 'pending'
               AND j.id <> ?
               AND j.status IN ('queued','processing')
               AND (j.created_at < ? OR (j.created_at = ? AND j.id < ?))
             LIMIT 1"
        );
        $stmt->execute([$hash, $jobId, $createdAt, $createdAt, $jobId]);
        return (bool) $stmt->fetchColumn();
    }

    private function completeFromCache(array $job, array $scan, array $cached): void
    {
        $this->db->beginTransaction();
        try {
            $this->db->prepare(
                'UPDATE scans SET verdict = ?, risk_score = ?, threat_category = ?, duration_ms = 0, scanned_at = UTC_TIMESTAMP() WHERE id = ?'
            )->execute([$cached['verdict'], $cached['risk_score'], $cached['threat_category'], $scan['id']]);
            $this->db->prepare(
                'INSERT INTO scan_results (scan_id, ip_address, ssl_status, ssl_issuer, ssl_valid_from, ssl_expires_at, domain_age_days, blacklist_listed, blacklist_total, redirect_chain, headers, recommendations, submitted_at, analyzed_at, completed_at, raw_response)
                 SELECT ?, ip_address, ssl_status, ssl_issuer, ssl_valid_from, ssl_expires_at, domain_age_days, blacklist_listed, blacklist_total, redirect_chain, headers, recommendations, submitted_at, analyzed_at, UTC_TIMESTAMP(), raw_response
                 FROM scan_results WHERE scan_id = ?'
            )->execute([$scan['id'], $cached['id']]);
            $this->db->prepare(
                'INSERT INTO scan_engines (scan_id, engine_name, flagged, label)
                 SELECT ?, engine_name, flagged, label FROM scan_engines WHERE scan_id = ?'
            )->execute([$scan['id'], $cached['id']]);
            $this->createNotification($scan, (string) $cached['verdict']);
            $this->db->prepare("UPDATE scan_jobs SET status = 'completed', last_error = NULL WHERE id = ?")
                ->execute([$job['id']]);
            $this->db->prepare('INSERT INTO audit_log (user_id, action, metadata) VALUES (?, ?, ?)')
                ->execute([$scan['user_id'], 'scan.cache_reused', json_encode(['scan_id' => $scan['id']])]);
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    private function lookupVirusTotal(string $url): array
    {
        $apiKey = env('VIRUSTOTAL_API_KEY');
        if ($apiKey === null || $apiKey === '') {
            $isDangerous = preg_match('/(phish|malware|dangerous|unsafe|bad|virus)/i', $url) === 1;
            return [
                'state' => 'complete',
                'stats' => [
                    'malicious' => $isDangerous ? 12 : 0,
                    'suspicious' => $isDangerous ? 4 : 0,
                    'harmless' => $isDangerous ? 68 : 84,
                ],
                'engines' => $isDangerous ? [
                    'Google Safebrowsing' => ['category' => 'malicious', 'result' => 'phishing'],
                    'Kaspersky' => ['category' => 'malicious', 'result' => 'malware'],
                ] : [],
                'raw' => [
                    'meta' => ['mock' => true],
                ],
            ];
        }
        $headers = ['x-apikey: ' . $apiKey];
        $urlId = rtrim(strtr(base64_encode($url), '+/', '-_'), '=');
        $response = HttpClient::request('GET', 'https://www.virustotal.com/api/v3/urls/' . rawurlencode($urlId), $headers);
        if ($response['status'] === 404) {
            $response = HttpClient::request('POST', 'https://www.virustotal.com/api/v3/urls', $headers, null, null, null, ['url' => $url]);
            if ($response['status'] < 200 || $response['status'] >= 300) {
                throw new RuntimeException('VirusTotal submission failed with HTTP ' . $response['status'] . '.');
            }
            return ['state' => 'pending'];
        }
        if ($response['status'] < 200 || $response['status'] >= 300) {
            throw new RuntimeException('VirusTotal lookup failed with HTTP ' . $response['status'] . '.');
        }
        $attributes = $response['body']['data']['attributes'] ?? [];
        $stats = $attributes['last_analysis_stats'] ?? [];
        if (!is_array($stats) || $stats === []) {
            return ['state' => 'pending'];
        }
        return [
            'state' => 'complete',
            'stats' => $stats,
            'engines' => is_array($attributes['last_analysis_results'] ?? null) ? $attributes['last_analysis_results'] : [],
            'raw' => $response['body'],
        ];
    }

    private function checkSslAndIp(string $host): array
    {
        $result = [
            'ip' => null,
            'ssl_status' => 'none',
            'ssl_issuer' => null,
            'ssl_valid_from' => null,
            'ssl_expires_at' => null,
        ];

        $ip = gethostbyname($host);
        if ($ip !== $host) {
            $result['ip'] = $ip;
        }

        // SSRF protection: block connections to internal/private IP ranges.
        if ($result['ip'] !== null && isBlockedIp($result['ip'])) {
            logSsrfAttempt('ssl://' . $host, $result['ip'], 'Blocked in SSL check');
            return $result;
        }

        $context = stream_context_create([
            'ssl' => [
                'capture_peer_cert' => true,
                'verify_peer' => false,
                'verify_peer_name' => false,
            ]
        ]);
        
        $socket = @stream_socket_client(
            "ssl://{$host}:443",
            $errno,
            $errstr,
            2.0,
            STREAM_CLIENT_CONNECT,
            $context
        );

        if ($socket) {
            $params = stream_context_get_params($socket);
            if (isset($params['options']['ssl']['peer_certificate'])) {
                $cert = $params['options']['ssl']['peer_certificate'];
                $certInfo = @openssl_x509_parse($cert);
                if (is_array($certInfo)) {
                    $result['ssl_status'] = 'valid';
                    $result['ssl_issuer'] = $certInfo['issuer']['O'] ?? $certInfo['issuer']['CN'] ?? 'Unknown';
                    
                    if (isset($certInfo['validFrom_time_t'])) {
                        $result['ssl_valid_from'] = date('Y-m-d H:i:s', $certInfo['validFrom_time_t']);
                    }
                    if (isset($certInfo['validTo_time_t'])) {
                        $result['ssl_expires_at'] = date('Y-m-d H:i:s', $certInfo['validTo_time_t']);
                        if ($certInfo['validTo_time_t'] < time()) {
                            $result['ssl_status'] = 'expired';
                        }
                    }
                }
            }
            fclose($socket);
        }

        return $result;
    }

    private function checkHttpDetails(string $url): array
    {
        // SSRF protection: validate URL before making outbound connections.
        try {
            validateUrlForOutbound($url);
        } catch (HttpException $e) {
            return ['redirects' => [], 'headers' => [], 'recommendations' => []];
        }

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HEADER, true);
        curl_setopt($ch, CURLOPT_NOBODY, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_MAXREDIRS, 3);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        // Restrict protocols to HTTP/HTTPS only — prevents file://, gopher://, etc.
        curl_setopt($ch, CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS);
        curl_setopt($ch, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS);
        
        $response = curl_exec($ch);
        $redirects = [];
        $headers = [];
        
        if ($response !== false) {
            $info = curl_getinfo($ch);
            $redirectCount = (int) ($info['redirect_count'] ?? 0);
            for ($i = 0; $i < $redirectCount; $i++) {
                $redirects[] = 'Redirect #' . ($i + 1);
            }
            
            $headerSize = $info['header_size'];
            $headerText = substr($response, 0, $headerSize);
            foreach (explode("\r\n", $headerText) as $line) {
                if (strpos($line, ':') !== false) {
                    list($key, $val) = explode(':', $line, 2);
                    $headers[trim($key)] = trim($val);
                }
            }
        }
        curl_close($ch);
        
        $recs = [];
        if (!isset($headers['Content-Security-Policy'])) {
            $recs[] = 'Implement Content-Security-Policy (CSP) header to prevent XSS attacks.';
        }
        if (!isset($headers['X-Frame-Options'])) {
            $recs[] = 'Implement X-Frame-Options header to protect against clickjacking.';
        }
        if (!isset($headers['X-Content-Type-Options'])) {
            $recs[] = 'Implement X-Content-Type-Options: nosniff header.';
        }
        if (!isset($headers['Strict-Transport-Security'])) {
            $recs[] = 'Enable HTTP Strict Transport Security (HSTS).';
        }
        
        return [
            'redirects' => $redirects,
            'headers' => $headers,
            'recommendations' => $recs,
        ];
    }

    private function checkDomainAge(string $domain): int
    {
        $parts = explode('.', $domain);
        $count = count($parts);
        if ($count < 2) return 365;
        $regDomain = $parts[$count - 2] . '.' . $parts[$count - 1];

        $ch = curl_init("https://rdap.org/domain/" . rawurlencode($regDomain));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 1);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        $res = curl_exec($ch);
        curl_close($ch);

        if ($res) {
            $data = json_decode($res, true);
            foreach ($data['events'] ?? [] as $event) {
                if (($event['eventAction'] ?? '') === 'registration') {
                    $dateStr = $event['eventDate'] ?? '';
                    if ($dateStr !== '') {
                        $time = strtotime($dateStr);
                        if ($time > 0) {
                            return (int) max(1, round((time() - $time) / 86400));
                        }
                    }
                }
            }
        }
        return 1460;
    }

    private function complete(array $job, array $scan, array $report, int $durationMs): void
    {
        $malicious = (int) ($report['stats']['malicious'] ?? 0);
        $suspicious = (int) ($report['stats']['suspicious'] ?? 0);
        $harmless = (int) ($report['stats']['harmless'] ?? 0);
        $verdict = $malicious > 0 ? 'dangerous' : ($suspicious > 0 ? 'suspicious' : 'safe');
        $risk = min(100, ($malicious * 15) + ($suspicious * 7));
        $category = $malicious > 0 ? 'malicious' : ($suspicious > 0 ? 'suspicious' : null);

        $sslAndIp = $this->checkSslAndIp($scan['hostname']);
        $http = $this->checkHttpDetails($scan['url']);
        $domainAge = $this->checkDomainAge($scan['hostname']);

        $this->db->beginTransaction();
        try {
            $this->db->prepare('UPDATE scans SET verdict = ?, risk_score = ?, threat_category = ?, duration_ms = ?, scanned_at = UTC_TIMESTAMP() WHERE id = ?')
                ->execute([$verdict, $risk, $category, $durationMs, $scan['id']]);
            $this->db->prepare('INSERT INTO scan_results (scan_id, ip_address, ssl_status, ssl_issuer, ssl_valid_from, ssl_expires_at, domain_age_days, blacklist_listed, blacklist_total, redirect_chain, headers, recommendations, submitted_at, analyzed_at, completed_at, raw_response) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP(), ?)')
                ->execute([
                    $scan['id'],
                    $sslAndIp['ip'],
                    $sslAndIp['ssl_status'],
                    $sslAndIp['ssl_issuer'],
                    $sslAndIp['ssl_valid_from'],
                    $sslAndIp['ssl_expires_at'],
                    $domainAge,
                    $malicious + $suspicious,
                    max(0, $malicious + $suspicious + $harmless),
                    json_encode($http['redirects']),
                    json_encode($http['headers']),
                    json_encode($http['recommendations']),
                    json_encode($report['raw'], JSON_THROW_ON_ERROR)
                ]);
            $engine = $this->db->prepare('INSERT INTO scan_engines (scan_id, engine_name, flagged, label) VALUES (?, ?, ?, ?)');
            foreach ($report['engines'] as $name => $engineResult) {
                if (!is_array($engineResult)) {
                    continue;
                }
                $categoryName = (string) ($engineResult['category'] ?? 'undetected');
                $label = substr((string) ($engineResult['result'] ?? $categoryName), 0, 120);
                $engine->execute([$scan['id'], substr((string) $name, 0, 80), in_array($categoryName, ['malicious', 'suspicious'], true) ? 1 : 0, $label]);
            }
            $this->createNotification($scan, $verdict);
            $this->db->prepare("UPDATE scan_jobs SET status = 'completed', last_error = NULL WHERE id = ?")->execute([$job['id']]);
            $this->db->prepare('INSERT INTO audit_log (user_id, action, metadata) VALUES (?, ?, ?)')
                ->execute([$scan['user_id'], 'scan.completed', json_encode(['scan_id' => $scan['id'], 'verdict' => $verdict])]);
            $this->db->commit();
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    private function createNotification(array $scan, string $verdict): void
    {
        $type = $verdict === 'safe' ? 'scan_complete' : 'threat_detected';
        $severity = $verdict === 'dangerous' ? 'critical' : ($verdict === 'suspicious' ? 'warning' : 'info');
        $title = $verdict === 'dangerous' ? 'Threat detected' : ($verdict === 'suspicious' ? 'Suspicious URL detected' : 'Scan completed');
        $message = $verdict === 'safe'
            ? "Scan completed for {$scan['hostname']}."
            : "Potential threat detected for {$scan['hostname']}.";
        $this->db->prepare('INSERT INTO notifications (id, user_id, scan_id, type, title, message, severity) VALUES (?, ?, ?, ?, ?, ?, ?)')
            ->execute([uuid(), $scan['user_id'], $scan['id'], $type, $title, $message, $severity]);
    }

    private function deferFollower(array $job, string $reason): void
    {
        $this->db->prepare(
            "UPDATE scan_jobs
             SET status = 'queued', attempts = GREATEST(attempts - 1, 0),
                 available_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 SECOND), last_error = ?
             WHERE id = ?"
        )->execute([substr($reason, 0, 500), $job['id']]);
    }

    private function retry(array $job, string $error): void
    {
        $attempts = (int) $job['attempts'] + 1;
        $message = substr($error, 0, 500);
        if ($attempts >= 7) {
            $this->db->beginTransaction();
            try {
                $this->db->prepare("UPDATE scan_jobs SET status = 'failed', last_error = ? WHERE id = ?")->execute([$message, $job['id']]);
                $this->db->prepare("UPDATE scans SET verdict = 'error', threat_category = 'scan_unavailable', scanned_at = UTC_TIMESTAMP() WHERE id = ?")->execute([$job['scan_id']]);
                $this->db->commit();
            } catch (Throwable $nested) {
                if ($this->db->inTransaction()) {
                    $this->db->rollBack();
                }
                throw $nested;
            }
            return;
        }
        
        $delaySeconds = match($attempts) {
            2 => 2,
            3 => 3,
            4 => 5,
            5 => 10,
            6 => 20,
            default => 30,
        };
        
        $this->db->prepare("UPDATE scan_jobs SET status = 'queued', available_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL {$delaySeconds} SECOND), last_error = ? WHERE id = ?")
            ->execute([$message, $job['id']]);
    }
}
