<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('GET');
$context = authenticatedContext();
$tableCheck = database()->prepare(
    'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = :schema_name AND table_name = :table_name'
);
$tableCheck->execute(['schema_name' => envValue('DB_NAME'), 'table_name' => 'blocked_urls']);
if ((int) $tableCheck->fetchColumn() === 0) {
    throw new ApiError(501, 'Blocked URLs are not available because the existing database has no blocked_urls table.');
}

$statement = database()->prepare(
    'SELECT id, url, reason, blocked_at FROM blocked_urls WHERE user_id = :user_id ORDER BY blocked_at DESC LIMIT 100'
);
$statement->execute(['user_id' => $context['user']['id']]);
respondJson(200, true, 'Blocked URLs fetched successfully.', ['items' => $statement->fetchAll()]);

