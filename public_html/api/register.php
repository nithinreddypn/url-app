<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';

requireMethod('POST');
$input = jsonInput();
$email = strtolower(requiredString($input, 'email', 191));
$fullName = requiredString($input, 'full_name', 120);
$password = requiredString($input, 'password', 128);

if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    throw new ApiError(422, 'Enter a valid email address.');
}
validatePasswordValue($password);

$db = database();
$existing = $db->prepare('SELECT 1 FROM users WHERE email = :email LIMIT 1');
$existing->execute(['email' => $email]);
if ($existing->fetchColumn()) {
    throw new ApiError(409, 'An account with this email already exists.');
}

$userId = uuidV4();
$db->beginTransaction();
try {
    $insert = $db->prepare(
        'INSERT INTO users (id, email, password_hash, full_name) '
        . 'VALUES (:id, :email, :password_hash, :full_name)'
    );
    $insert->execute([
        'id' => $userId,
        'email' => $email,
        'password_hash' => password_hash($password, passwordAlgorithm()),
        'full_name' => $fullName,
    ]);
    $role = $db->prepare('INSERT INTO user_roles (id, user_id, role) VALUES (:id, :user_id, :role)');
    $role->execute(['id' => uuidV4(), 'user_id' => $userId, 'role' => 'user']);
    $db->commit();
} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    if ($error instanceof PDOException && (string) $error->getCode() === '23000') {
        throw new ApiError(409, 'An account with this email already exists.');
    }
    throw $error;
}

$user = $db->prepare(
    'SELECT id, email, full_name, avatar_url, plan, email_verified_at, created_at, updated_at '
    . 'FROM users WHERE id = :id LIMIT 1'
);
$user->execute(['id' => $userId]);

respondJson(201, true, 'Account created successfully.', ['user' => publicUser($user->fetch())]);

