<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('POST');
$context = authenticatedContext();
$statement = database()->prepare(
    'UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE id = :id AND revoked_at IS NULL'
);
$statement->execute(['id' => $context['session_id']]);

respondJson(200, true, 'Logout successful.');

