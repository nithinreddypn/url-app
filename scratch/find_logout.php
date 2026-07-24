<?php
$f = file_get_contents('lib/services/auth_service.dart');
$lines = explode("\n", $f);
foreach ($lines as $i => $l) {
    if (stripos($l, 'logout') !== false || stripos($l, 'signout') !== false || stripos($l, 'sign_out') !== false || stripos($l, 'signOut') !== false) {
        echo ($i + 1) . ': ' . trim($l) . "\n";
    }
}
