<?php
function searchDir($dir, $terms) {
    $results = [];
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
    foreach ($files as $file) {
        if ($file->getExtension() !== 'dart') continue;
        $content = file_get_contents($file->getPathname());
        $lines = explode("\n", $content);
        foreach ($lines as $i => $l) {
            foreach ($terms as $term) {
                if (stripos($l, $term) !== false) {
                    echo basename($file->getPathname()) . ':' . ($i+1) . ': ' . trim($l) . "\n";
                    break;
                }
            }
        }
    }
}
searchDir('lib', ['signOut(', 'sign_out', 'SignOut', 'Sign Out', 'Sign out', 'sign out', 'Logout', 'logout']);
