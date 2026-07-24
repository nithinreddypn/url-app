<?php
declare(strict_types=1);

final class ApiError extends RuntimeException
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }
}

function loadEnvironment(string $path): void
{
    if (!is_file($path) || !is_readable($path)) {
        return;
    }
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        if ($key !== '' && getenv($key) === false) {
            $_ENV[$key] = trim($value, " \t\n\r\0\x0B\"");
        }
    }
}

function envValue(string $key, string $default = ''): string
{
    $value = getenv($key);
    if ($value !== false) {
        return (string) $value;
    }
    return isset($_ENV[$key]) ? (string) $_ENV[$key] : $default;
}

function envBool(string $key, bool $default): bool
{
    $value = envValue($key, $default ? 'true' : 'false');
    return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? $default;
}

function respondJson(int $status, bool $success, string $message, mixed $data = null): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: no-store');
    $response = ['success' => $success, 'message' => $message];
    if ($data !== null) {
        $response['data'] = $data;
    }
    echo json_encode($response, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function requireMethod(string ...$allowed): void
{
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    if (!in_array($method, $allowed, true)) {
        header('Allow: ' . implode(', ', $allowed));
        throw new ApiError(405, 'Method not allowed.');
    }
}

function jsonInput(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }
    $contentType = strtolower(trim(explode(';', $_SERVER['CONTENT_TYPE'] ?? '')[0]));
    if ($contentType !== 'application/json') {
        throw new ApiError(415, 'Content-Type must be application/json.');
    }
    try {
        $decoded = json_decode($raw, true, 64, JSON_THROW_ON_ERROR);
    } catch (JsonException) {
        throw new ApiError(400, 'Request body must contain valid JSON.');
    }
    if (!is_array($decoded) || array_is_list($decoded)) {
        throw new ApiError(400, 'The JSON body must be an object.');
    }
    return $decoded;
}

function requiredString(array $input, string $key, int $maxLength): string
{
    $value = $input[$key] ?? null;
    if (!is_string($value) || trim($value) === '') {
        throw new ApiError(422, $key . ' is required.');
    }
    $value = trim($value);
    if (strlen($value) > $maxLength) {
        throw new ApiError(422, $key . ' is too long.');
    }
    return $value;
}

function uuidV4(): string
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);
    return sprintf('%s-%s-%s-%s-%s', substr($hex, 0, 8), substr($hex, 8, 4), substr($hex, 12, 4), substr($hex, 16, 4), substr($hex, 20, 12));
}

function secureToken(): string
{
    return rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
}

function passwordAlgorithm(): string|int|null
{
    return defined('PASSWORD_ARGON2ID') ? PASSWORD_ARGON2ID : PASSWORD_DEFAULT;
}

function validatePasswordValue(string $password): void
{
    if (strlen($password) < 10 || strlen($password) > 128 ||
        !preg_match('/[a-z]/', $password) || !preg_match('/[A-Z]/', $password) ||
        !preg_match('/\d/', $password)) {
        throw new ApiError(422, 'Password must be 10–128 characters and include upper-case, lower-case, and a number.');
    }
}

function clientIpAddress(): ?string
{
    $ip = $_SERVER['REMOTE_ADDR'] ?? null;
    return is_string($ip) ? substr($ip, 0, 45) : null;
}

function clientUserAgent(): ?string
{
    $agent = $_SERVER['HTTP_USER_AGENT'] ?? null;
    return is_string($agent) ? substr($agent, 0, 255) : null;
}

function publicUser(array $user): array
{
    return [
        'id' => (string) $user['id'],
        'email' => (string) $user['email'],
        'full_name' => (string) $user['full_name'],
        'avatar_url' => $user['avatar_url'] ?? null,
        'plan' => (string) ($user['plan'] ?? 'free'),
        'email_verified_at' => $user['email_verified_at'] ?? null,
        'created_at' => $user['created_at'] ?? null,
        'updated_at' => $user['updated_at'] ?? null,
    ];
}

function configureCors(): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = array_values(array_filter(array_map('trim', explode(',', envValue('APP_ALLOWED_ORIGINS')))));
    if ($origin !== '') {
        if (!in_array($origin, $allowed, true)) {
            throw new ApiError(403, 'Origin is not allowed.');
        }
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
    }
    header('Access-Control-Allow-Methods: GET, POST, PATCH, OPTIONS');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept');
    header('Access-Control-Max-Age: 600');
    if (strtoupper($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}

function requestIsHttps(): bool
{
    if (($_SERVER['HTTPS'] ?? '') !== '' && strtolower((string) $_SERVER['HTTPS']) !== 'off') {
        return true;
    }
    return strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '')) === 'https';
}

loadEnvironment(dirname(__DIR__) . '/.env');

set_exception_handler(static function (Throwable $error): never {
    if ($error instanceof ApiError) {
        respondJson($error->status, false, $error->getMessage());
    }
    error_log(sprintf('[URL Defender API] %s in %s:%d', $error->getMessage(), $error->getFile(), $error->getLine()));
    respondJson(500, false, 'The server could not complete the request.');
});

configureCors();
if (envBool('REQUIRE_HTTPS', true) && PHP_SAPI !== 'cli' && !requestIsHttps()) {
    throw new ApiError(426, 'HTTPS is required.');
}

require_once __DIR__ . '/database.php';

