<?php
function searchDir($dir, $pattern) {
    $files = scandir($dir);
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;
        $path = $dir . '/' . $file;
        if (is_dir($path)) {
            searchDir($path, $pattern);
        } else if (pathinfo($path, PATHINFO_EXTENSION) === 'dart') {
            $content = file_get_contents($path);
            if (stripos($content, $pattern) !== false) {
                echo "Found in $path\n";
                // Print lines
                $lines = explode("\n", $content);
                foreach ($lines as $i => $line) {
                    if (stripos($line, $pattern) !== false) {
                        echo "  " . ($i + 1) . ": " . trim($line) . "\n";
                    }
                }
            }
        }
    }
}

searchDir('lib', 'VirusTotal Flags');
searchDir('lib', 'Heuristic Hits');
searchDir('lib', 'Community Reports');
