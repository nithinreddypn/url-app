<?php
declare(strict_types=1);

/**
 * Notification Controller — handles all notification CRUD and community broadcast operations.
 * Extracted from ScanController.php and extended with community threat notification support.
 */
final class NotificationController
{
    public function __construct(private readonly PDO $db)
    {
    }

    // ─── CRUD Operations (existing, enhanced) ───

    public function list(array $user): array
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
            'SELECT n.id, n.scan_id, n.related_report_id, n.type, n.title, n.message, n.severity, n.priority, n.category, n.read_at, n.created_at
             FROM notifications n
             LEFT JOIN scans s ON n.scan_id = s.id
             LEFT JOIN community_reports cr ON n.related_report_id = cr.id
             WHERE n.user_id = ? AND n.dismissed = 0
               AND (n.scan_id IS NULL OR s.id IS NOT NULL)
               AND (n.related_report_id IS NULL OR cr.id IS NOT NULL)
             ORDER BY n.created_at DESC
             LIMIT 100'
        );
        $stmt->execute([$user['id']]);
        return ['items' => $stmt->fetchAll()];
    }

    public function markRead(array $user, string $notificationId): array
    {
        $stmt = $this->db->prepare(
            'UPDATE notifications SET read_at = COALESCE(read_at, UTC_TIMESTAMP()) WHERE id = ? AND user_id = ? AND dismissed = 0'
        );
        $stmt->execute([$notificationId, $user['id']]);
        if ($stmt->rowCount() === 0) {
            throw new HttpException(404, 'Notification not found.');
        }
        return ['message' => 'Notification marked as read.'];
    }

    public function markAllRead(array $user): array
    {
        $stmt = $this->db->prepare(
            'UPDATE notifications SET read_at = COALESCE(read_at, UTC_TIMESTAMP()) WHERE user_id = ? AND dismissed = 0'
        );
        $stmt->execute([$user['id']]);
        return ['message' => 'All notifications marked as read.'];
    }

    public function clearAll(array $user): array
    {
        $stmt = $this->db->prepare('UPDATE notifications SET dismissed = 1 WHERE user_id = ?');
        $stmt->execute([$user['id']]);
        return ['message' => 'All notifications cleared.'];
    }

    // ─── Community Notification Broadcasting ───

    /**
     * Broadcast a community alert to ALL active users when a new report is submitted.
     */
    public function broadcastCommunityReport(string $reporterUserId, string $reportId, string $url, string $category): void
    {
        // 1. Notify the reporter
        $this->insertNotification(
            $reporterUserId,
            'community_report',
            'Report Submitted',
            'Your threat report for ' . $this->truncateUrl($url) . ' has been queued for verification. We\'ll notify you once the analysis completes.',
            'info',
            'low',
            'community',
            $reportId
        );

        // 2. Notify all OTHER active users
        $stmt = $this->db->prepare('SELECT id FROM users WHERE id != ? AND is_active = 1');
        $stmt->execute([$reporterUserId]);
        $userIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($userIds as $userId) {
            $this->insertNotification(
                $userId,
                'community_report',
                'New Community Threat Report',
                'A URL (' . $this->truncateUrl($url) . ') has been reported as ' . strtoupper(str_replace('_', ' ', $category)) . ' by the community. Verification is in progress. Stay alert until investigation completes.',
                'warning',
                'medium',
                'community',
                $reportId
            );
        }

        // 3. Notify all admins with priority alert
        $stmt = $this->db->query('SELECT user_id FROM user_roles WHERE role = "admin"');
        $adminIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($adminIds as $adminId) {
            $this->insertNotification(
                $adminId,
                'admin_review',
                'New Community Report — Review Required',
                'A new community threat report for ' . $this->truncateUrl($url) . ' (Category: ' . strtoupper(str_replace('_', ' ', $category)) . ') requires your review. Check the admin queue.',
                'warning',
                'high',
                'admin_review',
                $reportId
            );
        }
    }

    /**
     * Notify when verification is complete (worker finished processing).
     */
    public function notifyVerificationComplete(string $reportId, string $url, int $confidenceScore, string $status): void
    {
        // Get the original reporter
        $stmt = $this->db->prepare('SELECT reporter_id FROM community_reports WHERE id = ? LIMIT 1');
        $stmt->execute([$reportId]);
        $reporterId = $stmt->fetchColumn();

        if ($reporterId) {
            $this->insertNotification(
                $reporterId,
                'community_report',
                'Verification Complete — Awaiting Review',
                'Your report for ' . $this->truncateUrl($url) . ' has been verified with a confidence score of ' . $confidenceScore . '%. An administrator will review it shortly.',
                'info',
                'medium',
                'verification',
                $reportId
            );
        }

        // Notify admins with priority based on confidence
        $priority = $confidenceScore >= 90 ? 'critical' : ($confidenceScore >= 70 ? 'high' : 'medium');
        $severity = $confidenceScore >= 90 ? 'critical' : 'warning';

        $stmt = $this->db->query('SELECT user_id FROM user_roles WHERE role = "admin"');
        $adminIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($adminIds as $adminId) {
            $this->insertNotification(
                $adminId,
                'admin_review',
                'Verification Complete — ' . ucfirst($priority) . ' Priority',
                'Community report for ' . $this->truncateUrl($url) . ' verified with ' . $confidenceScore . '% confidence (Status: ' . strtoupper($status) . '). Review now.',
                $severity,
                $priority,
                'admin_review',
                $reportId
            );
        }
    }

    /**
     * Broadcast when admin approves a report.
     */
    public function notifyReportApproved(string $reportId, string $url, string $category, int $confidence): void
    {
        // Notify reporter
        $stmt = $this->db->prepare('SELECT reporter_id FROM community_reports WHERE id = ? LIMIT 1');
        $stmt->execute([$reportId]);
        $reporterId = $stmt->fetchColumn();

        if ($reporterId) {
            $this->insertNotification(
                $reporterId,
                'community_verified',
                'Threat Verified — Thank You!',
                'Your report for ' . $this->truncateUrl($url) . ' has been verified as ' . strtoupper(str_replace('_', ' ', $category)) . ' with ' . $confidence . '% confidence. Thank you for protecting the community!',
                'critical',
                'high',
                'verification',
                $reportId
            );
        }

        // Broadcast to all users
        $stmt = $this->db->prepare('SELECT id FROM users WHERE is_active = 1 AND id != ?');
        $stmt->execute([$reporterId ?: '']);
        $userIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($userIds as $userId) {
            $this->insertNotification(
                $userId,
                'community_verified',
                'Threat Verified — Community Intelligence Updated',
                'A URL (' . $this->truncateUrl($url) . ') has been verified as ' . strtoupper(str_replace('_', ' ', $category)) . '. Avoid this website. Community Intelligence has been updated.',
                'critical',
                'high',
                'threat_alert',
                $reportId
            );
        }
    }

    /**
     * Broadcast when admin rejects a report.
     */
    public function notifyReportRejected(string $reportId, string $url): void
    {
        // Notify reporter
        $stmt = $this->db->prepare('SELECT reporter_id FROM community_reports WHERE id = ? LIMIT 1');
        $stmt->execute([$reportId]);
        $reporterId = $stmt->fetchColumn();

        if ($reporterId) {
            $this->insertNotification(
                $reporterId,
                'community_rejected',
                'Verification Complete — No Threat Found',
                'Your report for ' . $this->truncateUrl($url) . ' was reviewed and determined to be safe. No further action is required. Thank you for helping improve URL Defender.',
                'info',
                'low',
                'verification',
                $reportId
            );
        }

        // Broadcast lighter notification to all users
        $stmt = $this->db->prepare('SELECT id FROM users WHERE is_active = 1 AND id != ?');
        $stmt->execute([$reporterId ?: '']);
        $userIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($userIds as $userId) {
            $this->insertNotification(
                $userId,
                'community_rejected',
                'Verification Complete — URL Cleared',
                'A previously reported URL (' . $this->truncateUrl($url) . ') has been determined to be safe after investigation. No further action is required.',
                'info',
                'low',
                'community',
                $reportId
            );
        }
    }

    // ─── Helpers ───

    private function insertNotification(
        string $userId,
        string $type,
        string $title,
        string $message,
        string $severity,
        string $priority,
        string $category,
        ?string $reportId = null
    ): void {
        if ($reportId !== null) {
            $stmt = $this->db->prepare('SELECT id FROM notifications WHERE user_id = ? AND related_report_id = ? AND type = ? AND dismissed = 0 LIMIT 1');
            $stmt->execute([$userId, $reportId, $type]);
            $existingId = $stmt->fetchColumn();
            if ($existingId !== false) {
                // Update existing notification to be unread and top of queue
                $this->db->prepare('UPDATE notifications SET created_at = CURRENT_TIMESTAMP, read_at = NULL, message = ?, title = ?, severity = ?, priority = ?, category = ? WHERE id = ?')
                    ->execute([$message, $title, $severity, $priority, $category, $existingId]);
                return;
            }
        }

        $this->db->prepare(
            'INSERT INTO notifications (id, user_id, related_report_id, type, title, message, severity, priority, category)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )->execute([
            uuid(),
            $userId,
            $reportId,
            $type,
            $title,
            $message,
            $severity,
            $priority,
            $category,
        ]);
    }

    private function truncateUrl(string $url): string
    {
        if (strlen($url) > 60) {
            return substr($url, 0, 57) . '...';
        }
        return $url;
    }
}
