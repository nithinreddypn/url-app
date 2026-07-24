<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';

try {
    $db = Database::connection();
} catch (DatabaseConnectionException) {
    fwrite(STDERR, "Unable to connect to the database.\n");
    exit(1);
}
$statements = [
    'DELETE FROM email_verifications WHERE expires_at < UTC_TIMESTAMP()',
    'DELETE FROM password_resets WHERE expires_at < UTC_TIMESTAMP()',
    'DELETE FROM auth_sessions WHERE expires_at < UTC_TIMESTAMP() OR (revoked_at IS NOT NULL AND revoked_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY))',
    'DELETE FROM login_attempts WHERE created_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 90 DAY)',
    'DELETE FROM audit_log WHERE created_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 365 DAY)',
    "DELETE FROM webhook_events WHERE processed_at IS NOT NULL AND processed_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 90 DAY)",
];
foreach ($statements as $statement) {
    $count = $db->exec($statement);
    fwrite(STDOUT, "{$count} rows removed\n");
}
