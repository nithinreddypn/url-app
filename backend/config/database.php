<?php
declare(strict_types=1);

/**
 * Safe exception used when the database is unavailable.
 *
 * The original PDO exception is retained for debug logging inside this file,
 * but callers only receive this generic exception and message.
 */
final class DatabaseConnectionException extends RuntimeException
{
}

final class Database
{
    private static ?PDO $connection = null;

    // ---------------------------------------------------------------------
    // Local configuration (XAMPP)
    // ---------------------------------------------------------------------
    private const LOCAL_CONFIGURATION = [
        'host' => 'localhost',
        'port' => '3306',
        'name' => 'url_defender',
        'user' => 'root',
        'password' => '',
    ];

    // ---------------------------------------------------------------------
    // Production configuration (Hostinger)
    // Replace only these four placeholders when deploying this backend.
    // This file lives outside backend/public and must not be web-accessible.
    // ---------------------------------------------------------------------
    private const PRODUCTION_CONFIGURATION = [
        'host' => 'HOSTINGER_DB_HOST',
        'port' => '3306',
        'name' => 'HOSTINGER_DB_NAME',
        'user' => 'HOSTINGER_DB_USER',
        'password' => 'HOSTINGER_DB_PASSWORD',
    ];

    // ---------------------------------------------------------------------
    // Connection creation
    // ---------------------------------------------------------------------
    public static function connection(): PDO
    {
        if (self::$connection instanceof PDO) {
            try {
                self::$connection->query('SELECT 1');
                return self::$connection;
            } catch (PDOException $e) {
                self::$connection = null;
            }
        }

        $configuration = self::isLocalRequest()
            ? self::LOCAL_CONFIGURATION
            : self::PRODUCTION_CONFIGURATION;

        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            $configuration['host'],
            $configuration['port'],
            $configuration['name'],
        );

        try {
            self::$connection = new PDO(
                $dsn,
                $configuration['user'],
                $configuration['password'],
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                    PDO::ATTR_STRINGIFY_FETCHES => false,
                ],
            );

            return self::$connection;
        } catch (PDOException $error) {
            self::handleConnectionError($error);
        }
    }

    private static function isLocalRequest(): bool
    {
        // The configured environment is authoritative. A physical phone reaches
        // the development server through the computer's LAN address, so its
        // Host header is not "localhost" even though the API is running locally.
        $environment = strtolower(self::environmentValue('APP_ENV', 'development'));
        if (in_array($environment, ['development', 'local', 'testing'], true)) {
            return true;
        }
        if ($environment === 'production') {
            return false;
        }

        $rawHost = strtolower((string) ($_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_NAME'] ?? ''));
        $parsedHost = $rawHost === '' ? null : parse_url('http://' . $rawHost, PHP_URL_HOST);
        $host = trim(is_string($parsedHost) ? $parsedHost : $rawHost, '[]');

        if (in_array($host, ['localhost', '127.0.0.1', '::1'], true)) {
            return true;
        }

        if ($host !== '') {
            return false;
        }

        // PHP's built-in server and local CLI tasks have no reliable HTTP host.
        return PHP_SAPI === 'cli';
    }

    // ---------------------------------------------------------------------
    // Error handling
    // ---------------------------------------------------------------------
    private static function handleConnectionError(PDOException $error): never
    {
        if (self::debugEnabled()) {
            error_log(sprintf(
                '[URL Defender Database] %s in %s:%d',
                $error->getMessage(),
                $error->getFile(),
                $error->getLine(),
            ));
        }

        throw new DatabaseConnectionException('Unable to connect to the database.');
    }

    private static function debugEnabled(): bool
    {
        return filter_var(
            self::environmentValue('APP_DEBUG', 'false'),
            FILTER_VALIDATE_BOOL,
        );
    }

    private static function environmentValue(string $key, string $default): string
    {
        if (function_exists('env')) {
            return (string) env($key, $default);
        }

        $value = getenv($key);
        return $value === false ? $default : (string) $value;
    }
}
