<?php
declare(strict_types=1);

final class AdminController
{
    public function __construct(private readonly PDO $db)
    {
    }

    public function users(array $actor): array
    {
        $this->requireRole($actor['id'], ['admin', 'moderator']);
        $limit = min(max((int) ($_GET['limit'] ?? 50), 1), 100);
        $stmt = $this->db->query('SELECT id, email, full_name, plan, email_verified_at, is_active, last_login_at, created_at FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT ' . $limit);
        return ['items' => $stmt->fetchAll()];
    }

    public function setUserActive(array $actor, string $userId, array $input): array
    {
        $this->requireRole($actor['id'], ['admin']);
        if (!array_key_exists('is_active', $input) || !is_bool($input['is_active'])) {
            throw new HttpException(422, 'is_active must be a boolean.');
        }
        if ($actor['id'] === $userId && !$input['is_active']) {
            throw new HttpException(422, 'You cannot deactivate your own account.');
        }
        $stmt = $this->db->prepare('UPDATE users SET is_active = ? WHERE id = ? AND deleted_at IS NULL');
        $stmt->execute([$input['is_active'] ? 1 : 0, $userId]);
        if ($stmt->rowCount() === 0) {
            throw new HttpException(404, 'User not found.');
        }
        if (!$input['is_active']) {
            $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND revoked_at IS NULL')->execute([$userId]);
        }
        $this->audit($actor['id'], 'admin.user_status_changed', ['target_user_id' => $userId, 'is_active' => $input['is_active']]);
        return ['message' => 'User status updated.'];
    }

    public function auditLog(array $actor): array
    {
        $this->requireRole($actor['id'], ['admin']);
        $limit = min(max((int) ($_GET['limit'] ?? 100), 1), 200);
        $stmt = $this->db->query('SELECT id, user_id, action, ip_address, user_agent, metadata, created_at FROM audit_log ORDER BY id DESC LIMIT ' . $limit);
        return ['items' => $stmt->fetchAll()];
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

    private function audit(string $userId, string $action, array $metadata): void
    {
        $this->db->prepare('INSERT INTO audit_log (user_id, action, ip_address, user_agent, metadata) VALUES (?, ?, ?, ?, ?)')
            ->execute([$userId, $action, clientIp(), userAgent(), json_encode($metadata)]);
    }
}
