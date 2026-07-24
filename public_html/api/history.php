<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('GET');
$context = authenticatedContext();
$limit = min(max(filter_input(INPUT_GET, 'limit', FILTER_VALIDATE_INT) ?: 50, 1), 100);
$verdict = isset($_GET['verdict']) ? strtolower(trim((string) $_GET['verdict'])) : '';
$allowedVerdicts = ['safe', 'suspicious', 'dangerous', 'pending', 'error'];
$parameters = ['user_id' => $context['user']['id']];
$where = 's.user_id = :user_id';
if ($verdict !== '') {
    if (!in_array($verdict, $allowedVerdicts, true)) {
        throw new ApiError(422, 'Invalid verdict filter.');
    }
    $where .= ' AND s.verdict = :verdict';
    $parameters['verdict'] = $verdict;
}
$statement = database()->prepare(
    'SELECT s.id, s.url, s.hostname, s.verdict, s.risk_score, s.threat_category, '
    . 's.duration_ms, s.scanned_at, s.created_at FROM scans s WHERE ' . $where
    . ' ORDER BY s.created_at DESC LIMIT ' . $limit
);
$statement->execute($parameters);

respondJson(200, true, 'Scan history fetched successfully.', ['items' => $statement->fetchAll()]);

