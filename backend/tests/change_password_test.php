<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/Mailer.php';
require dirname(__DIR__) . '/src/AuthController.php';

function expectPasswordTest(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$db = Database::connection();
$controller = new AuthController($db, new Mailer());
$userId = uuid();
$currentSessionId = uuid();
$otherSessionId = uuid();
$currentPassword = 'CurrentSecure2026!';
$newPassword = 'ChangedSecure2026!';
$email = 'password-test-' . bin2hex(random_bytes(6)) . '@example.invalid';

try {
    $db->prepare(
        'INSERT INTO users (id, email, password_hash, full_name, email_verified_at) VALUES (?, ?, ?, ?, UTC_TIMESTAMP())'
    )->execute([$userId, $email, password_hash($currentPassword, PASSWORD_ARGON2ID), 'Password Test']);
    $sessionInsert = $db->prepare(
        'INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR))'
    );
    $sessionInsert->execute([$currentSessionId, $userId, hash('sha256', random_bytes(32))]);
    $sessionInsert->execute([$otherSessionId, $userId, hash('sha256', random_bytes(32))]);
    $session = ['id' => $userId, 'session_id' => $currentSessionId];

    $wrongPasswordRejected = false;
    try {
        $controller->changePassword($session, [
            'current_password' => 'WrongCurrent2026!',
            'new_password' => $newPassword,
        ]);
    } catch (HttpException $error) {
        $wrongPasswordRejected = $error->status === 422;
    }
    expectPasswordTest($wrongPasswordRejected, 'Wrong current password was accepted.');
    $hashAfterFailure = $db->query("SELECT password_hash FROM users WHERE id = " . $db->quote($userId))->fetchColumn();
    expectPasswordTest(password_verify($currentPassword, (string) $hashAfterFailure), 'Password changed after a rejected request.');

    $response = $controller->changePassword($session, [
        'current_password' => $currentPassword,
        'new_password' => $newPassword,
    ]);
    expectPasswordTest($response['message'] === 'Password changed successfully.', 'Success response is incorrect.');
    $newHash = $db->query("SELECT password_hash FROM users WHERE id = " . $db->quote($userId))->fetchColumn();
    expectPasswordTest(password_verify($newPassword, (string) $newHash), 'Correct current password did not update the password.');

    $sessions = $db->prepare('SELECT id, revoked_at FROM auth_sessions WHERE user_id = ?');
    $sessions->execute([$userId]);
    $sessionStates = [];
    foreach ($sessions->fetchAll() as $row) {
        $sessionStates[$row['id']] = $row['revoked_at'];
    }
    expectPasswordTest($sessionStates[$currentSessionId] === null, 'Current session was revoked.');
    expectPasswordTest($sessionStates[$otherSessionId] !== null, 'Other session was not revoked.');
    $notification = $db->prepare(
        "SELECT COUNT(*) FROM notifications WHERE user_id = ? AND type = 'security' AND title = 'Password changed'"
    );
    $notification->execute([$userId]);
    expectPasswordTest((int) $notification->fetchColumn() === 1, 'Password-change notification was not created.');

    echo "Change-password security tests passed.\n";
} finally {
    $db->prepare('DELETE FROM audit_log WHERE user_id = ?')->execute([$userId]);
    $db->prepare('DELETE FROM users WHERE id = ?')->execute([$userId]);
}
