<?php
$file = 'lib/views/scan_screen.dart';
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (strpos($line, '_showScanDetails') !== false) {
        echo "Line " . ($i + 1) . ": " . trim($line) . "\n";
    }
}
