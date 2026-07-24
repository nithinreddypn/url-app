<?php
function searchDir($dir) {
    $files = scandir($dir);
    foreach ($files as $file) {
        if ($file === '.' || $file === '..') continue;
        $path = $dir . '/' . $file;
        if (is_dir($path)) {
            searchDir($path);
        } else if (pathinfo($path, PATHINFO_EXTENSION) === 'php') {
            $content = file_get_contents($path);
            $lines = explode("\n", $content);
            foreach ($lines as $i => $line) {
                if (stripos($line, 'rate_limit') !== false || stripos($line, 'ratelimit') !== false || stripos($line, 'throttle') !== false) {
                    echo "Found in $path on line " . ($i + 1) . ": " . trim($line) . "\n";
                }
            }
        }
    }
}
searchDir('backend/src');
