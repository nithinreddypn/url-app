<?php
declare(strict_types=1);

/** Returns the single PDO connection used by all API endpoints. */
function database(): PDO
{
    static $connection = null;
    if ($connection instanceof PDO) {
        return $connection;
    }

    $host = envValue('DB_HOST');
    $port = envValue('DB_PORT', '3306');
    $name = envValue('DB_NAME');
    $user = envValue('DB_USER');
    $pass = envValue('DB_PASS');
    if ($host === '' || $name === '' || $user === '') {
        throw new RuntimeException('Database configuration is incomplete.');
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $host,
        $port,
        $name,
    );

    $connection = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::ATTR_STRINGIFY_FETCHES => false,
        PDO::ATTR_TIMEOUT => 10,
    ]);

    return $connection;
}

