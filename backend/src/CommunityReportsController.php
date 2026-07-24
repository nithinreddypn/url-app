<?php
declare(strict_types=1);

final class CommunityReportsController
{
    private readonly NotificationController $notifier;

    public function __construct(private readonly PDO $db)
    {
        $this->notifier = new NotificationController($db);
    }

    /**
     * Submit a new threat report.
     */
    public function submitReport(array $user, array $input): array
    {
        $url = trim((string) ($input['url'] ?? ''));
        $category = trim((string) ($input['threat_category'] ?? ''));
        $description = trim((string) ($input['description'] ?? ''));

        $screenshotUrl = null;
        if (isset($input['screenshot_base64']) && is_string($input['screenshot_base64']) && $input['screenshot_base64'] !== '') {
            try {
                $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $input['screenshot_base64']));
                
                // 1. Store to temp/staging location
                $stagingDir = dirname(__DIR__) . '/public/uploads/screenshots/staging';
                if (!is_dir($stagingDir)) {
                    mkdir($stagingDir, 0755, true);
                }
                $tempFilename = uuid() . '.png';
                $tempPath = $stagingDir . '/' . $tempFilename;
                file_put_contents($tempPath, $data);
                
                $screenshotValid = true;
                
                // 2. STUB: Run a virus/malware scan on the file
                // exec("clamscan " . escapeshellarg($tempPath), $output, $returnVar);
                // if ($returnVar !== 0) { $screenshotValid = false; }
                
                // 3. Validate image size/dimensions (Max 5MB)
                $fileSize = filesize($tempPath);
                if ($fileSize > 5 * 1024 * 1024) {
                    $screenshotValid = false;
                }
                
                $imageInfo = @getimagesize($tempPath);
                if ($imageInfo === false) {
                    $screenshotValid = false;
                } else {
                    $width = $imageInfo[0];
                    $height = $imageInfo[1];
                    // Reasonable bounds: 100px to 8000px
                    if ($width < 100 || $width > 8000 || $height < 100 || $height > 8000) {
                        $screenshotValid = false;
                    }
                }
                
                // 4. STUB: Run content moderation
                // e.g. AWS Rekognition / Google Cloud Vision SafeSearch API check
                // $moderationPassed = callModerationApi($tempPath);
                // if (!$moderationPassed) { $screenshotValid = false; }
                
                if ($screenshotValid) {
                    // 5. Move to permanent storage
                    $permDir = dirname(__DIR__) . '/public/uploads/screenshots';
                    if (!is_dir($permDir)) {
                        mkdir($permDir, 0755, true);
                    }
                    $filename = uuid() . '.png';
                    rename($tempPath, $permDir . '/' . $filename);
                    $screenshotUrl = '/uploads/screenshots/' . $filename;
                } else {
                    @unlink($tempPath);
                    $rejectOnFail = (bool) env('REJECT_REPORT_ON_SCREENSHOT_FAIL', 'false');
                    if ($rejectOnFail) {
                        throw new HttpException(422, 'Screenshot validation failed. Report rejected.');
                    }
                }
            } catch (HttpException $e) {
                throw $e;
            } catch (Throwable $e) {
                // Accept report without screenshot
            }
        }

        if ($url === '' || $category === '' || $description === '') {
            throw new HttpException(422, 'URL, Threat Category, and Description are required.');
        }

        $validCategories = [
            'phishing', 
            'malware', 
            'scam', 
            'fake_login', 
            'crypto_scam', 
            'spam', 
            'unsafe_download',
            'fake_banking',
            'investment_scam',
            'fake_shopping',
            'identity_theft',
            'other'
        ];
        if (!in_array($category, $validCategories, true)) {
            throw new HttpException(422, 'Invalid threat category.');
        }

        // 1. Blocked check
        $stmt = $this->db->prepare('SELECT 1 FROM blocked_reporters WHERE user_id = ? LIMIT 1');
        $stmt->execute([$user['id']]);
        if ($stmt->fetchColumn()) {
            throw new HttpException(403, 'Your account has been suspended from submitting reports.');
        }

        // Check if user has accumulated too many false reports
        $stmt = $this->db->prepare('SELECT false_reports FROM reporter_reputation WHERE user_id = ? LIMIT 1');
        $stmt->execute([$user['id']]);
        $falseReports = $stmt->fetchColumn();
        if ($falseReports !== false && (int) $falseReports >= (int) env('MAX_FALSE_REPORTS_THRESHOLD', '3')) {
            throw new HttpException(403, 'Your account has been temporarily suspended from submitting reports due to multiple false reports.');
        }

        // 2. Rate limiting check (10 per user per day, 50 per IP per day)
        $ip = clientIp() ?? '127.0.0.1';
        $userLimit = 10;
        $ipLimit = 50;

        $stmt = $this->db->prepare('SELECT COUNT(*) FROM community_reports WHERE reporter_id = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)');
        $stmt->execute([$user['id']]);
        if ((int) $stmt->fetchColumn() >= $userLimit) {
            throw new HttpException(429, 'Daily report limit reached (max 10 per day).');
        }

        $stmt = $this->db->prepare('SELECT COUNT(*) FROM community_reports cr JOIN audit_log al ON cr.id = JSON_UNQUOTE(JSON_EXTRACT(al.metadata, "$.report_id")) WHERE al.ip_address = ? AND cr.created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)');
        $stmt->execute([$ip]);
        if ((int) $stmt->fetchColumn() >= $ipLimit) {
            throw new HttpException(429, 'IP report limit reached (max 50 per day).');
        }

        // Normalize URL
        $normalized = normalizeUrlInput($url);
        $urlHash = $normalized['normalized_url_hash'];

        $this->db->beginTransaction();
        try {
            // 3. User Reputation setup
            $stmt = $this->db->prepare('SELECT trust_score FROM reporter_reputation WHERE user_id = ? LIMIT 1');
            $stmt->execute([$user['id']]);
            $trustScore = $stmt->fetchColumn();
            if ($trustScore === false) {
                $trustScore = 50;
                $this->db->prepare('INSERT INTO reporter_reputation (user_id, trust_score) VALUES (?, ?)')
                    ->execute([$user['id'], $trustScore]);
            }
            $trustScore = (int) $trustScore;
            $voteWeight = max(0.1, min(1.0, $trustScore / 100.0));

            // 4. Duplicate Check
            $stmt = $this->db->prepare('SELECT id, report_count FROM community_reports WHERE normalized_url_hash = ? AND merged_into IS NULL LIMIT 1 FOR UPDATE');
            $stmt->execute([$urlHash]);
            $existing = $stmt->fetch();

            $reportId = uuid();
            if ($existing) {
                $reportId = $existing['id'];
                
                // Check if user already reported or voted on this existing report
                $stmt = $this->db->prepare('SELECT 1 FROM community_report_votes WHERE report_id = ? AND user_id = ? LIMIT 1');
                $stmt->execute([$reportId, $user['id']]);
                if ($stmt->fetchColumn()) {
                    throw new HttpException(400, 'You have already reported this URL.');
                }
                
                $this->db->prepare('UPDATE community_reports SET report_count = report_count + 1, last_reported_at = NOW() WHERE id = ?')
                    ->execute([$reportId]);
            } else {
                $this->db->prepare('INSERT INTO community_reports (id, reporter_id, url, normalized_url_hash, threat_category, description, screenshot_url, report_count) VALUES (?, ?, ?, ?, ?, ?, ?, 1)')
                    ->execute([$reportId, $user['id'], $normalized['url'], $urlHash, $category, $description, $screenshotUrl]);
            }

            // Insert user's vote
            $voteId = uuid();
            $this->db->prepare('INSERT INTO community_report_votes (id, report_id, user_id, vote_type, vote_weight) VALUES (?, ?, ?, "confirm_threat", ?)')
                ->execute([$voteId, $reportId, $user['id'], $voteWeight]);

            // Queue verification job
            $jobId = uuid();
            $this->db->prepare('INSERT INTO report_jobs (id, report_id, status) VALUES (?, ?, "queued")')
                ->execute([$jobId, $reportId]);

            $this->audit($user['id'], 'community.report_submitted', ['report_id' => $reportId, 'url' => $normalized['url']]);
            $this->db->commit();

            // Broadcast community notifications (after commit)
            try {
                $this->notifier->broadcastCommunityReport($user['id'], $reportId, $normalized['url'], $category);
            } catch (Throwable $ne) {
                // Don't fail the report submission if notifications fail
                error_log('Notification broadcast failed: ' . $ne->getMessage());
            }

            return ['success' => true, 'message' => 'Report submitted successfully and queued for analysis.', 'report_id' => $reportId];
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Submit an Upvote or Downvote for a report.
     */
    public function submitVote(array $user, array $input): array
    {
        $reportId = trim((string) ($input['report_id'] ?? ''));
        $voteType = trim((string) ($input['vote_type'] ?? ''));

        if ($reportId === '' || ($voteType !== 'confirm_threat' && $voteType !== 'looks_safe')) {
            throw new HttpException(422, 'Report ID and valid Vote Type (confirm_threat or looks_safe) are required.');
        }

        // Check if report exists
        $stmt = $this->db->prepare('SELECT 1 FROM community_reports WHERE id = ? LIMIT 1');
        $stmt->execute([$reportId]);
        if (!$stmt->fetchColumn()) {
            throw new HttpException(404, 'Report not found.');
        }

        // Get user reputation trust score
        $stmt = $this->db->prepare('SELECT trust_score FROM reporter_reputation WHERE user_id = ? LIMIT 1');
        $stmt->execute([$user['id']]);
        $trustScore = $stmt->fetchColumn();
        if ($trustScore === false) {
            $trustScore = 50;
            $this->db->prepare('INSERT INTO reporter_reputation (user_id, trust_score) VALUES (?, 50)')
                ->execute([$user['id']]);
        }
        $voteWeight = max(0.1, min(1.0, (int) $trustScore / 100.0));

        $this->db->beginTransaction();
        try {
            // Check if already voted
            $stmt = $this->db->prepare('SELECT id, vote_type FROM community_report_votes WHERE report_id = ? AND user_id = ? LIMIT 1');
            $stmt->execute([$reportId, $user['id']]);
            $existingVote = $stmt->fetch();

            if ($existingVote) {
                if ($existingVote['vote_type'] === $voteType) {
                    // Retract the vote if clicking the same one (toggle off)
                    $this->db->prepare('DELETE FROM community_report_votes WHERE id = ?')
                        ->execute([$existingVote['id']]);
                    $votedType = 'retracted';
                } else {
                    // Update existing vote
                    $this->db->prepare('UPDATE community_report_votes SET vote_type = ?, vote_weight = ? WHERE id = ?')
                        ->execute([$voteType, $voteWeight, $existingVote['id']]);
                    $votedType = $voteType;
                }
            } else {
                // Insert new vote
                $this->db->prepare('INSERT INTO community_report_votes (id, report_id, user_id, vote_type, vote_weight) VALUES (?, ?, ?, ?, ?)')
                    ->execute([uuid(), $reportId, $user['id'], $voteType, $voteWeight]);
                $votedType = $voteType;
            }

            // Queue a new verification job to update score asynchronously
            $this->db->prepare('INSERT INTO report_jobs (id, report_id, status) VALUES (?, ?, "queued")')
                ->execute([uuid(), $reportId]);

            $this->audit($user['id'], 'community.report_voted', ['report_id' => $reportId, 'vote_type' => $votedType]);
            $this->db->commit();
            return ['success' => true, 'message' => $votedType === 'retracted' ? 'Vote retracted successfully.' : 'Vote recorded successfully.'];
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Get verified community intelligence.
     */
    public function getVerified(array $user): array
    {
        $stmt = $this->db->query('SELECT url, threat_category, reporter_count, confidence_score, approved_at FROM verified_community_intelligence ORDER BY approved_at DESC LIMIT 50');
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get report status for a specific URL query.
     */
    public function checkStatus(array $user): array
    {
        $url = trim((string) ($_GET['url'] ?? ''));
        if ($url === '') {
            throw new HttpException(422, 'URL parameter is required.');
        }
        $normalized = normalizeUrlInput($url);
        $urlHash = $normalized['normalized_url_hash'];

        // Check verified database first
        $stmt = $this->db->prepare('SELECT * FROM verified_community_intelligence WHERE url_hash = ? LIMIT 1');
        $stmt->execute([$urlHash]);
        $verified = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($verified) {
            return ['status' => 'verified', 'data' => $verified];
        }

        // Check pending reports
        $stmt = $this->db->prepare('SELECT * FROM community_reports WHERE normalized_url_hash = ? AND merged_into IS NULL LIMIT 1');
        $stmt->execute([$urlHash]);
        $pending = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($pending) {
            return ['status' => 'pending', 'data' => [
                'id' => $pending['id'],
                'url' => $pending['url'],
                'threat_category' => $pending['threat_category'],
                'reporter_count' => (int) $pending['report_count'],
                'verification_status' => $pending['verification_status'],
            ]];
        }

        return ['status' => 'clean', 'data' => null];
    }

    /**
     * Get top community threat categories.
     */
    public function getCategories(array $user): array
    {
        $stmt = $this->db->query('SELECT threat_category, COUNT(*) as count FROM verified_community_intelligence GROUP BY threat_category');
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get trending threat reports.
     */
    public function getTrending(array $user): array
    {
        $stmt = $this->db->query('SELECT url, threat_category, reporter_count, confidence_score FROM verified_community_intelligence ORDER BY reporter_count DESC LIMIT 5');
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get top reported items.
     */
    public function getTopReports(array $user): array
    {
        $stmt = $this->db->query('SELECT url, threat_category, reporter_count, confidence_score FROM verified_community_intelligence ORDER BY confidence_score DESC LIMIT 5');
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get details for a specific domain name.
     */
    public function getDomainDetails(array $user, string $domain): array
    {
        $stmt = $this->db->prepare('SELECT url, threat_category, reporter_count, confidence_score FROM verified_community_intelligence WHERE url LIKE ?');
        $stmt->execute(['%' . $domain . '%']);
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * List all reports for the admin review queue.
     */
    public function getAdminReports(array $actor): array
    {
        $this->requireRole($actor['id'], ['admin']);
        $tab = trim((string) ($_GET['tab'] ?? 'highest_priority'));

        $sql = 'SELECT cr.*, vr.confidence_score, u.full_name as reporter_name FROM community_reports cr
                LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
                LEFT JOIN users u ON cr.reporter_id = u.id ';

        $params = [];
        if ($tab === 'highest_priority') {
            $sql .= 'WHERE cr.priority_score >= 120 AND cr.verification_status NOT IN ("approved", "rejected", "duplicate") AND cr.merged_into IS NULL ORDER BY cr.priority_score DESC';
        } else if ($tab === 'high') {
            $sql .= 'WHERE cr.priority_score >= 80 AND cr.priority_score < 120 AND cr.verification_status NOT IN ("approved", "rejected", "duplicate") AND cr.merged_into IS NULL ORDER BY cr.priority_score DESC';
        } else if ($tab === 'medium') {
            $sql .= 'WHERE cr.priority_score >= 40 AND cr.priority_score < 80 AND cr.verification_status NOT IN ("approved", "rejected", "duplicate") AND cr.merged_into IS NULL ORDER BY cr.priority_score DESC';
        } else if ($tab === 'low') {
            $sql .= 'WHERE cr.priority_score < 40 AND cr.verification_status NOT IN ("approved", "rejected", "duplicate") AND cr.merged_into IS NULL ORDER BY cr.priority_score DESC';
        } else if ($tab === 'duplicate') {
            $sql .= 'WHERE cr.verification_status = "duplicate" ORDER BY cr.last_reported_at DESC';
        } else if ($tab === 'approved') {
            $sql .= 'WHERE cr.verification_status = "approved" ORDER BY cr.approved_at DESC';
        } else if ($tab === 'rejected') {
            $sql .= 'WHERE cr.verification_status = "rejected" ORDER BY cr.approved_at DESC';
        } else {
            // Default fallback
            $sql .= 'WHERE cr.verification_status NOT IN ("approved", "rejected", "duplicate") AND cr.merged_into IS NULL ORDER BY cr.priority_score DESC';
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($items as &$item) {
            $score = (double) ($item['priority_score'] ?? 0.0);
            if ($score >= 120.0) {
                $item['priority_tier'] = '🔥 Highest';
            } else if ($score >= 80.0) {
                $item['priority_tier'] = 'High';
            } else if ($score >= 40.0) {
                $item['priority_tier'] = 'Medium';
            } else {
                $item['priority_tier'] = 'Low';
            }
        }
        return ['items' => $items];
    }

    /**
     * Approve a reported threat.
     */
    public function approveReport(array $actor, string $reportId): array
    {
        $this->requireRole($actor['id'], ['admin']);

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare('SELECT * FROM community_reports WHERE id = ? LIMIT 1 FOR UPDATE');
            $stmt->execute([$reportId]);
            $report = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$report) {
                throw new HttpException(404, 'Report not found.');
            }

            // Update report status
            $this->db->prepare('UPDATE community_reports SET verification_status = "approved", approved_by = ?, approved_at = NOW() WHERE id = ?')
                ->execute([$actor['id'], $reportId]);

            // Fetch confidence score
            $stmt = $this->db->prepare('SELECT confidence_score FROM report_verification_results WHERE report_id = ? LIMIT 1');
            $stmt->execute([$reportId]);
            $confidence = (int) ($stmt->fetchColumn() ?: 75);

            // Write into public verified layer
            $this->db->prepare('INSERT INTO verified_community_intelligence (url_hash, url, threat_category, reporter_count, confidence_score, approved_at) VALUES (?, ?, ?, ?, ?, NOW()) ON DUPLICATE KEY UPDATE reporter_count = VALUES(reporter_count), confidence_score = VALUES(confidence_score), last_updated = NOW()')
                ->execute([$report['normalized_url_hash'], $report['url'], $report['threat_category'], $report['report_count'], $confidence]);

            // Reward the reporter reputation
            $stmt = $this->db->prepare('SELECT trust_score FROM reporter_reputation WHERE user_id = ? LIMIT 1');
            $stmt->execute([$report['reporter_id']]);
            $score = $stmt->fetchColumn();
            if ($score !== false) {
                $newScore = min(100, ((int) $score) + 15);
                $this->db->prepare('UPDATE reporter_reputation SET trust_score = ?, approved_reports = approved_reports + 1 WHERE user_id = ?')
                    ->execute([$newScore, $report['reporter_id']]);
            }

            // Write to admin audit log
            $this->db->prepare('INSERT INTO admin_audit_log (id, admin_id, action, target_id, notes) VALUES (?, ?, ?, ?, ?)')
                ->execute([uuid(), $actor['id'], 'approve', $reportId, 'Approved URL: ' . $report['url']]);

            $this->audit($actor['id'], 'admin.report_approved', ['report_id' => $reportId, 'url' => $report['url']]);
            $this->db->commit();

            // Broadcast approval notifications (after commit)
            try {
                $this->notifier->notifyReportApproved($reportId, $report['url'], $report['threat_category'], $confidence);
            } catch (Throwable $ne) {
                error_log('Approval notification failed: ' . $ne->getMessage());
            }

            return ['success' => true, 'message' => 'Report approved and added to community threat intelligence.'];
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Reject a reported threat.
     */
    public function rejectReport(array $actor, string $reportId): array
    {
        $this->requireRole($actor['id'], ['admin']);

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare('SELECT * FROM community_reports WHERE id = ? LIMIT 1 FOR UPDATE');
            $stmt->execute([$reportId]);
            $report = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$report) {
                throw new HttpException(404, 'Report not found.');
            }

            // Update status
            $this->db->prepare('UPDATE community_reports SET verification_status = "rejected", approved_by = ?, approved_at = NOW() WHERE id = ?')
                ->execute([$actor['id'], $reportId]);

            // Deprecate reporter reputation
            $stmt = $this->db->prepare('SELECT trust_score FROM reporter_reputation WHERE user_id = ? LIMIT 1');
            $stmt->execute([$report['reporter_id']]);
            $score = $stmt->fetchColumn();
            if ($score !== false) {
                // Increment false_reports since it was proven wrong/rejected!
                $newScore = max(0, ((int) $score) - 10);
                $this->db->prepare('UPDATE reporter_reputation SET trust_score = ?, rejected_reports = rejected_reports + 1, false_reports = false_reports + 1 WHERE user_id = ?')
                    ->execute([$newScore, $report['reporter_id']]);
            }

            // Write to admin audit log
            $this->db->prepare('INSERT INTO admin_audit_log (id, admin_id, action, target_id, notes) VALUES (?, ?, ?, ?, ?)')
                ->execute([uuid(), $actor['id'], 'reject', $reportId, 'Rejected URL: ' . $report['url']]);

            $this->audit($actor['id'], 'admin.report_rejected', ['report_id' => $reportId, 'url' => $report['url']]);
            $this->db->commit();

            // Broadcast rejection notifications (after commit)
            try {
                $this->notifier->notifyReportRejected($reportId, $report['url']);
            } catch (Throwable $ne) {
                error_log('Rejection notification failed: ' . $ne->getMessage());
            }

            return ['success' => true, 'message' => 'Report rejected successfully.'];
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Merge a duplicate report into a primary target report.
     */
    public function mergeReport(array $actor, string $reportId, string $targetId): array
    {
        $this->requireRole($actor['id'], ['admin']);

        if ($reportId === $targetId) {
            throw new HttpException(400, 'Cannot merge a report into itself.');
        }

        $this->db->beginTransaction();
        try {
            // Get duplicate report
            $stmt = $this->db->prepare('SELECT * FROM community_reports WHERE id = ? LIMIT 1 FOR UPDATE');
            $stmt->execute([$reportId]);
            $duplicate = $stmt->fetch(PDO::FETCH_ASSOC);

            // Get target report
            $stmt = $this->db->prepare('SELECT * FROM community_reports WHERE id = ? LIMIT 1 FOR UPDATE');
            $stmt->execute([$targetId]);
            $target = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$duplicate || !$target) {
                throw new HttpException(404, 'One or both reports not found.');
            }

            if ($duplicate['merged_into'] !== null) {
                throw new HttpException(400, 'Duplicate report is already merged.');
            }

            // Update duplicate report status and link
            $this->db->prepare('UPDATE community_reports SET verification_status = "duplicate", merged_into = ? WHERE id = ?')
                ->execute([$targetId, $reportId]);

            // Add duplicate count to target report
            $newCount = (int) $target['report_count'] + (int) $duplicate['report_count'];
            $newPriority = (double) $target['priority_score'] + ((int) $duplicate['report_count'] * 2.0); // simple priority boost

            $this->db->prepare('UPDATE community_reports SET report_count = ?, priority_score = ? WHERE id = ?')
                ->execute([$newCount, $newPriority, $targetId]);

            // Write admin audit log
            $this->db->prepare('INSERT INTO admin_audit_log (id, admin_id, action, target_id, notes) VALUES (?, ?, ?, ?, ?)')
                ->execute([uuid(), $actor['id'], 'merge', $reportId, 'Merged into target ID: ' . $targetId]);

            $this->audit($actor['id'], 'admin.report_merged', ['report_id' => $reportId, 'target_id' => $targetId]);
            $this->db->commit();

            return ['success' => true, 'message' => 'Report successfully merged into target.'];
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Block a reporter account.
     */
    public function blockReporter(array $actor, string $userId): array
    {
        $this->requireRole($actor['id'], ['admin']);

        $stmt = $this->db->prepare('SELECT 1 FROM users WHERE id = ? LIMIT 1');
        $stmt->execute([$userId]);
        if (!$stmt->fetchColumn()) {
            throw new HttpException(404, 'User not found.');
        }

        $this->db->prepare('INSERT INTO blocked_reporters (id, user_id, reason) VALUES (?, ?, ?)')
            ->execute([uuid(), $userId, 'Malicious activity/false reporting']);

        // Write to admin audit log
        $this->db->prepare('INSERT INTO admin_audit_log (id, admin_id, action, target_id, notes) VALUES (?, ?, ?, ?, ?)')
            ->execute([uuid(), $actor['id'], 'block_reporter', $userId, 'Blocked reporter ID: ' . $userId]);

        $this->audit($actor['id'], 'admin.reporter_blocked', ['target_user_id' => $userId]);
        return ['success' => true, 'message' => 'Reporter account successfully blocked.'];
    }

    /**
     * Get the current user's reporter reputation.
     */
    public function getMyReputation(array $user): array
    {
        $stmt = $this->db->prepare('SELECT trust_score, approved_reports, rejected_reports, false_reports, last_updated FROM reporter_reputation WHERE user_id = ? LIMIT 1');
        $stmt->execute([$user['id']]);
        $rep = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$rep) {
            $rep = [
                'trust_score' => 50,
                'approved_reports' => 0,
                'rejected_reports' => 0,
                'false_reports' => 0,
                'last_updated' => null,
            ];
        }

        // Count total reports submitted by this user
        $stmt = $this->db->prepare('SELECT COUNT(*) FROM community_report_votes WHERE user_id = ? AND vote_type = "confirm_threat"');
        $stmt->execute([$user['id']]);
        $totalReports = (int) $stmt->fetchColumn();

        // Count total votes cast
        $stmt = $this->db->prepare('SELECT COUNT(*) FROM community_report_votes WHERE user_id = ?');
        $stmt->execute([$user['id']]);
        $totalVotes = (int) $stmt->fetchColumn();

        // Determine badge/rank
        $trustScore = (int) $rep['trust_score'];
        $badge = 'Newcomer';
        if ($trustScore >= 90) {
            $badge = 'Elite Defender';
        } else if ($trustScore >= 75) {
            $badge = 'Trusted Reporter';
        } else if ($trustScore >= 60) {
            $badge = 'Active Contributor';
        } else if ($trustScore >= 40) {
            $badge = 'Community Member';
        }

        return [
            'trust_score' => $trustScore,
            'badge' => $badge,
            'approved_reports' => (int) $rep['approved_reports'],
            'rejected_reports' => (int) $rep['rejected_reports'],
            'false_reports' => (int) $rep['false_reports'],
            'total_reports_submitted' => $totalReports,
            'total_votes_cast' => $totalVotes,
            'last_updated' => $rep['last_updated'],
        ];
    }

    private function requireRole(string $userId, array $roles): void
    {
        $marks = implode(',', array_fill(0, count($roles), '?'));
        $stmt = $this->db->prepare("SELECT 1 FROM user_roles WHERE user_id = ? AND role IN ({$marks}) LIMIT 1");
        $stmt->execute([$userId, ...$roles]);
        if (!$stmt->fetchColumn()) {
            throw new HttpException(403, 'You do not have permission to access this endpoint.');
        }
    }

    // ─── New Query Methods ───

    /**
     * Get the current user's own submitted reports with verification status and timeline.
     */
    public function getMyReports(array $user): array
    {
        $stmt = $this->db->prepare(
            'SELECT cr.id, cr.url, cr.threat_category, cr.description, cr.report_count,
                    cr.verification_status, cr.priority_score, cr.created_at, cr.last_reported_at,
                    cr.approved_by, cr.approved_at, cr.screenshot_url,
                    vr.confidence_score,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "confirm_threat") as confirm_votes,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "looks_safe") as safe_votes
             FROM community_reports cr
             LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
             WHERE cr.reporter_id = ? AND cr.merged_into IS NULL
             ORDER BY cr.created_at DESC
             LIMIT 50'
        );
        $stmt->execute([$user['id']]);
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Add timeline data for each report
        foreach ($items as &$item) {
            $item['timeline'] = $this->buildTimeline($item);
        }

        return ['items' => $items];
    }

    /**
     * Get detailed view of a single report including verification, votes, and timeline.
     */
    public function getReportDetail(array $user, string $reportId): array
    {
        $stmt = $this->db->prepare(
            'SELECT cr.*, vr.confidence_score, vr.computed_at as verification_computed_at,
                    u.full_name as reporter_name,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "confirm_threat") as confirm_votes,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "looks_safe") as safe_votes
             FROM community_reports cr
             LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
             LEFT JOIN users u ON cr.reporter_id = u.id
             WHERE cr.id = ?
             LIMIT 1'
        );
        $stmt->execute([$reportId]);
        $report = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$report) {
            throw new HttpException(404, 'Report not found.');
        }

        // Add timeline
        $report['timeline'] = $this->buildTimeline($report);

        // Get vote breakdown
        $stmt = $this->db->prepare(
            'SELECT crv.vote_type, crv.vote_weight, crv.created_at, u.full_name as voter_name
             FROM community_report_votes crv
             LEFT JOIN users u ON crv.user_id = u.id
             WHERE crv.report_id = ?
             ORDER BY crv.created_at DESC
             LIMIT 20'
        );
        $stmt->execute([$reportId]);
        $report['votes'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Get admin audit notes
        $stmt = $this->db->prepare(
            'SELECT action, notes, created_at FROM admin_audit_log WHERE target_id = ? ORDER BY created_at DESC LIMIT 10'
        );
        $stmt->execute([$reportId]);
        $report['admin_notes'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Check if current user has voted
        $stmt = $this->db->prepare('SELECT vote_type FROM community_report_votes WHERE report_id = ? AND user_id = ? LIMIT 1');
        $stmt->execute([$reportId, $user['id']]);
        $report['user_vote'] = $stmt->fetchColumn() ?: null;

        // Fetch corresponding scan record if it exists
        $stmt = $this->db->prepare('SELECT id, verdict, risk_score, threat_category, scanned_at FROM scans WHERE normalized_url_hash = ? AND verdict != "pending" ORDER BY created_at DESC LIMIT 1');
        $stmt->execute([$report['normalized_url_hash']]);
        $scan = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($scan) {
            $report['scan'] = $scan;
            // Fetch scan_results details
            $stmt = $this->db->prepare('SELECT ip_address, blacklist_listed, blacklist_total, domain_age_days, redirect_chain, recommendations FROM scan_results WHERE scan_id = ? LIMIT 1');
            $stmt->execute([$scan['id']]);
            $report['scan_results'] = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;

            // Fetch scan_engines details
            $stmt = $this->db->prepare('SELECT engine_name, flagged, label FROM scan_engines WHERE scan_id = ?');
            $stmt->execute([$scan['id']]);
            $report['scan_engines'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } else {
            $report['scan'] = null;
            $report['scan_results'] = null;
            $report['scan_engines'] = [];
        }

        return ['report' => $report];
    }

    /**
     * Get latest community reports (all users).
     */
    public function getLatestReports(array $user): array
    {
        $stmt = $this->db->query(
            'SELECT cr.id, cr.url, cr.threat_category, cr.description, cr.report_count,
                    cr.verification_status, cr.priority_score, cr.created_at, cr.last_reported_at,
                    vr.confidence_score, u.full_name as reporter_name,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "confirm_threat") as confirm_votes,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "looks_safe") as safe_votes
             FROM community_reports cr
             LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
             LEFT JOIN users u ON cr.reporter_id = u.id
             WHERE cr.merged_into IS NULL
             ORDER BY cr.created_at DESC
             LIMIT 30'
        );
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get reports pending verification.
     */
    public function getPendingReports(array $user): array
    {
        $this->requireRole($user['id'], ['admin', 'moderator']);
        $stmt = $this->db->query(
            'SELECT cr.id, cr.url, cr.threat_category, cr.report_count,
                    cr.verification_status, cr.created_at, u.full_name as reporter_name,
                    (SELECT COUNT(*) FROM community_report_votes WHERE report_id = cr.id AND vote_type = "confirm_threat") as confirm_votes
             FROM community_reports cr
             LEFT JOIN users u ON cr.reporter_id = u.id
             WHERE cr.verification_status IN ("pending", "needs_review", "high_risk") AND cr.merged_into IS NULL
             ORDER BY cr.priority_score DESC
             LIMIT 20'
        );
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get most reported URLs.
     */
    public function getMostReported(array $user): array
    {
        $stmt = $this->db->query(
            'SELECT cr.id, cr.url, cr.threat_category, cr.report_count, cr.verification_status,
                    vr.confidence_score, cr.created_at
             FROM community_reports cr
             LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
             WHERE cr.merged_into IS NULL
             ORDER BY cr.report_count DESC
             LIMIT 10'
        );
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get recently verified (approved) reports.
     */
    public function getRecentlyVerified(array $user): array
    {
        $stmt = $this->db->query(
            'SELECT cr.id, cr.url, cr.threat_category, cr.report_count, cr.approved_at,
                    vr.confidence_score, u.full_name as reporter_name
             FROM community_reports cr
             LEFT JOIN report_verification_results vr ON cr.id = vr.report_id
             LEFT JOIN users u ON cr.reporter_id = u.id
             WHERE cr.verification_status = "approved"
             ORDER BY cr.approved_at DESC
             LIMIT 10'
        );
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    /**
     * Get community statistics.
     */
    public function getCommunityStats(array $user): array
    {
        $totalReports = (int) $this->db->query('SELECT COUNT(*) FROM community_reports WHERE merged_into IS NULL')->fetchColumn();
        $verifiedCount = (int) $this->db->query('SELECT COUNT(*) FROM community_reports WHERE verification_status = "approved"')->fetchColumn();
        $pendingCount = (int) $this->db->query('SELECT COUNT(*) FROM community_reports WHERE verification_status IN ("pending", "needs_review", "high_risk") AND merged_into IS NULL')->fetchColumn();
        $rejectedCount = (int) $this->db->query('SELECT COUNT(*) FROM community_reports WHERE verification_status = "rejected"')->fetchColumn();
        $activeReporters = (int) $this->db->query('SELECT COUNT(DISTINCT reporter_id) FROM community_reports')->fetchColumn();
        $avgConfidence = (float) $this->db->query('SELECT COALESCE(AVG(confidence_score), 0) FROM report_verification_results')->fetchColumn();
        $totalVotes = (int) $this->db->query('SELECT COUNT(*) FROM community_report_votes')->fetchColumn();

        // Category breakdown
        $stmt = $this->db->query('SELECT threat_category, COUNT(*) as count FROM community_reports WHERE merged_into IS NULL GROUP BY threat_category ORDER BY count DESC');
        $categoryBreakdown = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'total_reports' => $totalReports,
            'verified_count' => $verifiedCount,
            'pending_count' => $pendingCount,
            'rejected_count' => $rejectedCount,
            'active_reporters' => $activeReporters,
            'avg_confidence' => round($avgConfidence, 1),
            'total_votes' => $totalVotes,
            'category_breakdown' => $categoryBreakdown,
        ];
    }

    /**
     * Build a verification timeline for a report.
     */
    private function buildTimeline(array $report): array
    {
        $timeline = [];

        // Step 1: Submitted
        $timeline[] = [
            'step' => 'submitted',
            'title' => 'Report Submitted',
            'status' => 'completed',
            'timestamp' => $report['created_at'] ?? null,
        ];

        // Step 2: Queued for verification
        $timeline[] = [
            'step' => 'queued',
            'title' => 'Queued for Verification',
            'status' => 'completed',
            'timestamp' => $report['created_at'] ?? null,
        ];

        // Step 3: Verification
        $verificationStatus = $report['verification_status'] ?? 'pending';
        $hasConfidence = isset($report['confidence_score']) && $report['confidence_score'] !== null;
        $timeline[] = [
            'step' => 'verification',
            'title' => 'Automated Verification',
            'status' => $hasConfidence ? 'completed' : ($verificationStatus === 'pending' ? 'active' : 'completed'),
            'timestamp' => $report['verification_computed_at'] ?? null,
            'confidence' => $report['confidence_score'] ?? null,
        ];

        // Step 4: Admin Review
        $isApprovedOrRejected = in_array($verificationStatus, ['approved', 'rejected'], true);
        $needsReview = in_array($verificationStatus, ['high_risk', 'needs_review'], true);
        $timeline[] = [
            'step' => 'admin_review',
            'title' => 'Admin Review',
            'status' => $isApprovedOrRejected ? 'completed' : ($needsReview ? 'active' : 'pending'),
            'timestamp' => $report['approved_at'] ?? null,
        ];

        // Step 5: Decision
        $timeline[] = [
            'step' => 'decision',
            'title' => $verificationStatus === 'approved' ? 'Approved — Threat Verified' : ($verificationStatus === 'rejected' ? 'Rejected — No Threat Found' : 'Awaiting Decision'),
            'status' => $isApprovedOrRejected ? 'completed' : 'pending',
            'timestamp' => $report['approved_at'] ?? null,
        ];

        return $timeline;
    }

    /**
     * Get community notifications/alerts.
     */
    public function getAlerts(array $user): array
    {
        // Dismiss older duplicate community_report notifications to prevent race-condition duplicates
        $this->db->prepare('
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
        ')->execute([$user['id'], $user['id']]);

        // Dismiss older duplicate admin_review notifications to prevent race-condition duplicates
        $this->db->prepare('
            UPDATE notifications n1
            INNER JOIN (
                SELECT related_report_id, MAX(created_at) as max_created
                FROM notifications
                WHERE user_id = ? AND type = "admin_review" AND related_report_id IS NOT NULL AND dismissed = 0
                GROUP BY related_report_id
                HAVING COUNT(*) > 1
            ) n2 ON n1.related_report_id = n2.related_report_id
            SET n1.dismissed = 1
            WHERE n1.user_id = ? AND n1.type = "admin_review" AND n1.created_at < n2.max_created AND n1.dismissed = 0
        ')->execute([$user['id'], $user['id']]);

        $stmt = $this->db->prepare(
            'SELECT n.id, n.related_report_id, n.type, n.title, n.message, n.severity, n.priority, n.category, n.created_at
             FROM notifications n
             LEFT JOIN community_reports cr ON n.related_report_id = cr.id
             WHERE n.user_id = ? AND n.dismissed = 0 AND n.type IN ("community_report", "community_verified", "community_rejected", "threat_alert")
               AND (n.related_report_id IS NULL OR cr.id IS NOT NULL)
             ORDER BY n.created_at DESC
             LIMIT 50'
        );
        $stmt->execute([$user['id']]);
        return ['items' => $stmt->fetchAll(PDO::FETCH_ASSOC)];
    }

    private function audit(string $userId, string $action, array $metadata): void
    {
        $this->db->prepare('INSERT INTO audit_log (user_id, action, ip_address, user_agent, metadata) VALUES (?, ?, ?, ?, ?)')
            ->execute([$userId, $action, clientIp(), userAgent(), json_encode($metadata)]);
    }
}
