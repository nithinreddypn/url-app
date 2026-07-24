<?php
$file = 'lib/views/scan_detail_screen.dart';
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (strpos($line, 'VirusTotal Flags') !== false || strpos($line, 'Heuristic Hits') !== false || strpos($line, 'Community Reports') !== false) {
        echo "Line " . ($i + 1) . ": " . trim($line) . "\n";
        for ($j = max(0, $i - 5); $j < min($i + 10, count($lines)); $j++) {
            echo "  " . ($j + 1) . ": " . $lines[$j] . "\n";
        }
    }
}
