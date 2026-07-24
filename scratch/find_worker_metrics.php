<?php
$file = 'backend/src/ScanWorker.php';
if (!file_exists($file)) {
    $file = 'backend/cli/scan_worker.php';
}
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (strpos($line, 'heuristic') !== false || strpos($line, 'community') !== false || strpos($line, 'blacklist') !== false) {
        echo "Line " . ($i + 1) . ": " . trim($line) . "\n";
    }
}
