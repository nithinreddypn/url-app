<?php
$files = ['backend/public/index.php', 'backend/src/Support.php'];
foreach ($files as $file) {
    if (!file_exists($file)) continue;
    $content = file_get_contents($file);
    $lines = explode("\n", $content);
    foreach ($lines as $i => $line) {
        if (stripos($line, 'rate') !== false || stripos($line, 'limit') !== false || stripos($line, 'throttle') !== false) {
            echo "Match in $file on line " . ($i + 1) . ": " . trim($line) . "\n";
        }
    }
}
