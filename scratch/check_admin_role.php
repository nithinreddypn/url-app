<?php
$content = file_get_contents('backend/src/CommunityReportsController.php');
$lines = explode("\n", $content);
$methods = ['getAdminReports', 'approveReport', 'rejectReport', 'mergeReport', 'blockReporter', 'getPendingReports'];
foreach ($lines as $i => $line) {
    foreach ($methods as $m) {
        if (strpos($line, "function $m") !== false) {
            echo "Line " . ($i + 1) . ":\n";
            for ($j = $i; $j < min($i + 5, count($lines)); $j++) {
                echo "  " . ($j + 1) . ": " . trim($lines[$j]) . "\n";
            }
            echo "\n";
        }
    }
}
