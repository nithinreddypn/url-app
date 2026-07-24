<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';

requireMethod('POST');
$input = jsonInput();
$email = strtolower(requiredString($input, 'email', 191));
$password = requiredString($input, 'password', 128);
if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    throw new ApiError(422, 'Enter a valid email address.');
}

$db = database();
$recentFailures = $db->prepare(
    'SELECT SUM(email = :email) AS email_failures, SUM(ip_address = :ip_address) AS ip_failures '
    . 'FROM login_attempts WHERE success = 0 AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE) '
    . 'AND (email = :email_filter OR ip_address = :ip_filter)'
);
$recentFailures->execute([
    'email' => $email,
    'ip_address' => clientIpAddress(),
    'email_filter' => $email,
    'ip_filter' => clientIpAddress(),
]);
$failureCounts = $recentFailures->fetch() ?: [];
if ((int) ($failureCounts['email_failures'] ?? 0) >= 10 || (int) ($failureCounts['ip_failures'] ?? 0) >= 25) {
    throw new ApiError(429, 'Too many sign-in attempts. Try again in 15 minutes.');
}

$find = $db->prepare(
    'SELECT id, email, password_hash, full_name, avatar_url, plan, email_verified_at, '
    . 'is_active, deleted_at, created_at, updated_at FROM users WHERE email = :email LIMIT 1'
);
$find->execute(['email' => $email]);
$user = $find->fetch();
$dummyHash = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.';
$valid = password_verify($password, is_array($user) ? (string) $user['password_hash'] : $dummyHash);
$active = is_array($user) && (int) $user['is_active'] === 1 && $user['deleted_at'] === null;

$attempt = $db->prepare(
    'INSERT INTO login_attempts (email, user_id, ip_address, user_agent, success, failure_reason) '
    . 'VALUES (:email, :user_id, :ip_address, :user_agent, :success, :failure_reason)'
);
$attempt->execute([
    'email' => $email,
    'user_id' => is_array($user) ? $user['id'] : null,
    'ip_address' => clientIpAddress(),
    'user_agent' => clientUserAgent(),
    'success' => $valid && $active ? 1 : 0,
    'failure_reason' => $valid && $active ? null : 'invalid_credentials',
]);

if (!$valid) {
    throw new ApiError(401, 'Invalid credentials.');
}
if (!$active) {
    throw new ApiError(403, 'Your account has been disabled. Please contact support.');
}

if (password_needs_rehash((string) $user['password_hash'], passwordAlgorithm())) {
    $rehash = $db->prepare('UPDATE users SET password_hash = :password_hash WHERE id = :id');
    $rehash->execute(['password_hash' => password_hash($password, passwordAlgorithm()), 'id' => $user['id']]);
}

$token = secureToken();
$days = min(max((int) envValue('SESSION_LIFETIME_DAYS', '30'), 1), 90);
$session = $db->prepare(
    'INSERT INTO auth_sessions (id, user_id, token_hash, ip_address, user_agent, expires_at) '
    . 'VALUES (:id, :user_id, :token_hash, :ip_address, :user_agent, DATE_ADD(UTC_TIMESTAMP(), INTERVAL ' . $days . ' DAY))'
);
$session->execute([
    'id' => uuidV4(),
    'user_id' => $user['id'],
    'token_hash' => hash('sha256', $token),
    'ip_address' => clientIpAddress(),
    'user_agent' => clientUserAgent(),
]);
$db->prepare('UPDATE users SET last_login_at = UTC_TIMESTAMP() WHERE id = :id')->execute(['id' => $user['id']]);
unset($user['password_hash'], $user['is_active'], $user['deleted_at']);

respondJson(200, true, 'Login successful.', ['token' => $token, 'user' => publicUser($user)]);
