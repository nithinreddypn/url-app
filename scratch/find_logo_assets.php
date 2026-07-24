<?php
$dirs = ['assets', 'lib'];
foreach ($dirs as $dir) {
    if (!is_dir($dir)) continue;
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
    foreach ($files as $file) {
        if ($file->isDir()) continue;
        $name = strtolower($file->getFilename());
        if (strpos($name, 'logo') !== false || strpos($name, 'icon') !== false || strpos($name, 'shield') !== false) {
            echo $file->getPathname() . " (Size: " . $file->getSize() . " bytes)\n";
        }
    }
}
