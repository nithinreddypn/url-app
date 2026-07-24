<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/HttpClient.php';
require dirname(__DIR__) . '/src/ScanWorker.php';

$workerId = gethostname() . ':' . getmypid();
$once = in_array('--once', $argv, true);
do {
    $worked = false;
    try {
        $worker = new ScanWorker(Database::connection());
        $worked = $worker->processNext($workerId);
    } catch (Throwable $e) {
        fwrite(STDERR, "ScanWorker loop error: " . $e->getMessage() . "\n");
    }
    if (!$once && !$worked) {
        sleep(3);
    }
} while (!$once);
