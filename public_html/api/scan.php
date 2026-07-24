<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('POST');
$context = authenticatedContext();
$input = jsonInput();
$url = requiredString($input, 'url', 2048);
if (filter_var($url, FILTER_VALIDATE_URL) === false) {
    throw new ApiError(422, 'Enter a valid URL.');
}
$parts = parse_url($url);
$scheme = strtolower((string) ($parts['scheme'] ?? ''));
$hostname = strtolower((string) ($parts['host'] ?? ''));
if (!in_array($scheme, ['http', 'https'], true) || $hostname === '') {
    throw new ApiError(422, 'Only HTTP and HTTPS URLs can be scanned.');
}

$id = uuidV4();
$statement = database()->prepare(
    'INSERT INTO scans (id, user_id, url, hostname, verdict, risk_score) '
    . 'VALUES (:id, :user_id, :url, :hostname, :verdict, :risk_score)'
);
$statement->execute([
    'id' => $id,
    'user_id' => $context['user']['id'],
    'url' => $url,
    'hostname' => substr($hostname, 0, 255),
    'verdict' => 'pending',
    'risk_score' => 0,
]);

$fetch = database()->prepare(
    'SELECT id, url, hostname, verdict, risk_score, threat_category, duration_ms, scanned_at, created_at '
    . 'FROM scans WHERE id = :id AND user_id = :user_id LIMIT 1'
);
$fetch->execute(['id' => $id, 'user_id' => $context['user']['id']]);
respondJson(201, true, 'Scan saved successfully.', ['scan' => $fetch->fetch()]);

