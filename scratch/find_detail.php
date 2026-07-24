<?php
$file = 'lib/views/community_report_detail_page.dart';
$content = file_get_contents($file);
$lines = explode("\n", $content);
foreach ($lines as $i => $line) {
    if (strpos($line, 'submitVote') !== false || strpos($line, 'vote') !== false || strpos($line, 'confirm_threat') !== false) {
        echo "Line " . ($i + 1) . ": " . trim($line) . "\n";
    }
}
