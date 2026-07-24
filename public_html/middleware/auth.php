<?php
declare(strict_types=1);

function bearerToken(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!is_string($header) || !preg_match('/^Bearer\s+([^\s]+)$/i', trim($header), $match)) {
        throw new ApiError(401, 'A valid bearer token is required.');
    }
    return $match[1];
}

/** @return array{user: array, session_id: string} */
function authenticatedContext(): array
{
    $tokenHash = hash('sha256', bearerToken());
    $statement = database()->prepare(
        'SELECT s.id AS session_id, u.id, u.email, u.full_name, u.avatar_url, u.plan, '
        . 'u.email_verified_at, u.created_at, u.updated_at '
        . 'FROM auth_sessions s INNER JOIN users u ON u.id = s.user_id '
        . 'WHERE s.token_hash = :token_hash AND s.revoked_at IS NULL '
        . 'AND s.expires_at > UTC_TIMESTAMP() AND u.is_active = 1 AND u.deleted_at IS NULL LIMIT 1'
    );
    $statement->execute(['token_hash' => $tokenHash]);
    $row = $statement->fetch();
    if (!is_array($row)) {
        throw new ApiError(401, 'Your session is invalid or has expired.');
    }
    $sessionId = (string) $row['session_id'];
    unset($row['session_id']);
    return ['user' => $row, 'session_id' => $sessionId];
}

