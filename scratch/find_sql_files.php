<?php
$dir = 'backend';
if (is_dir($dir)) {
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
    foreach ($files as $file) {
        if ($file->getExtension() === 'sql') {
            echo $file->getPathname() . "\n";
        }
    }
}
