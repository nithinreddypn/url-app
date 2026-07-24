<?php
$dir = 'lib';
$files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
foreach ($files as $file) {
    if ($file->getExtension() !== 'dart') continue;
    $content = file_get_contents($file->getPathname());
    if (strpos($content, 'logo.png') !== false) {
        echo $file->getPathname() . "\n";
    }
}
