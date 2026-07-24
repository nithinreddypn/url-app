<?php
/**
 * URL Defender — Hostinger Extraction Helper
 * 
 * Upload this file to your public_html folder and visit:
 * https://moccasin-chicken-542251.hostingersite.com/extract.php
 */
header('Content-Type: text/plain');

$zip = new ZipArchive;
if ($zip->open('backend.zip') === TRUE) {
    // PHP's ZipArchive automatically normalizes backslashes to folders on Linux
    $zip->extractTo('.');
    $zip->close();
    echo "SUCCESS: backend.zip extracted successfully with correct folder structure!\n";
    echo "You can now safely delete extract.php and backend.zip from public_html.";
} else {
    echo "ERROR: Failed to open backend.zip. Make sure it is uploaded in public_html.";
}
