<?php
$f = file_get_contents('lib/views/auth/reset_password_screen.dart');
$lines = explode("\n", $f);
foreach ($lines as $i => $l) {
    if (strpos($l, 'logo.png') !== false) {
        echo ($i + 1) . ': ' . trim($l) . "\n";
    }
}
