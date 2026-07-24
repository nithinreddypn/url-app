<?php
$dir = 'lib';
$files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
foreach ($files as $file) {
    $name = basename($file->getPathname());
    if ($name === 'account_card.dart' || $name === 'settings_screen.dart') {
        echo $file->getPathname() . "\n";
    }
}
