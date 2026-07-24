<?php
$file = 'lib/views/scan_detail_screen.dart';
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (stripos($line, 'virustotal') !== false || stripos($line, 'heuristic') !== false) {
        echo "Line " . ($i + 1) . ": " . trim($line) . "\n";
    }
}
