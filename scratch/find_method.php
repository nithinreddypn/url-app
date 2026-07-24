<?php
$file = 'backend/src/CommunityReportsController.php';
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (strpos($line, 'function getAlerts') !== false) {
        echo "Found getAlerts at line " . ($i + 1) . "\n";
        for ($j = $i; $j < min($i + 30, count($lines)); $j++) {
            echo ($j + 1) . ": " . $lines[$j] . "\n";
        }
    }
    if (strpos($line, 'function submitVote') !== false) {
        echo "Found submitVote at line " . ($i + 1) . "\n";
        for ($j = $i; $j < min($i + 40, count($lines)); $j++) {
            echo ($j + 1) . ": " . $lines[$j] . "\n";
        }
    }
}
