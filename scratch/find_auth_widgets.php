<?php
$dir = 'lib';
$files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
foreach ($files as $file) {
    if (basename($file->getPathname()) === 'auth_widgets.dart') {
        echo $file->getPathname() . "\n";
    }
}
