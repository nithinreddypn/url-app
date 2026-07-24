<?php
function scanForSqlInjection($dir) {
    $files = scandir($dir);
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;
        $path = $dir . '/' . $file;
        if (is_dir($path)) {
            scanForSqlInjection($path);
        } else if (pathinfo($path, PATHINFO_EXTENSION) === 'php') {
            $content = file_get_contents($path);
            $lines = explode("\n", $content);
            foreach ($lines as $i => $line) {
                // Check if prepare or query contains string concatenation or variables
                if (preg_match('/->(?:prepare|query)\s*\(\s*["\'].*(?:\$[a-zA-Z0-9_]+|\.\s*\$[a-zA-Z0-9_]+)/i', $line)) {
                    // Exclude SQL lines that only have LIMIT concatenation or don't look vulnerable, but report anyway
                    echo "Possible SQLi in $path on line " . ($i + 1) . ": " . trim($line) . "\n";
                }
            }
        }
    }
}

scanForSqlInjection('backend/src');
