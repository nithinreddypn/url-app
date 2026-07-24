<?php
$files = ['backend/src/AuthController.php', 'backend/src/CommunityReportsController.php'];
foreach ($files as $file) {
    if (!file_exists($file)) continue;
    $content = file_get_contents($file);
    $lines = explode("\n", $content);
    foreach ($lines as $i => $line) {
        if (stripos($line, 'upload') !== false || stripos($line, 'avatar') !== false || stripos($line, 'screenshot') !== false || stripos($line, 'move_uploaded_file') !== false || stripos($line, 'file_put_contents') !== false) {
            echo "Match in $file on line " . ($i + 1) . ": " . trim($line) . "\n";
        }
    }
}
