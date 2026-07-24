<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';

$db = Database::connection();
$statement = $db->prepare(
    "UPDATE users
     SET avatar_url = SUBSTRING(avatar_url, LOCATE('/uploads/avatars/', avatar_url))
     WHERE avatar_url LIKE '%/uploads/avatars/%'
       AND avatar_url NOT LIKE '/uploads/avatars/%'"
);
$statement->execute();

echo sprintf("Normalized %d managed avatar path(s).\n", $statement->rowCount());
