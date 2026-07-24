<?php
declare(strict_types=1);

final class HttpException extends RuntimeException
{
    public function __construct(public readonly int $status, string $message)
    {
        parent::__construct($message);
    }
}

function loadEnv(string $path): void
{
    if (!is_file($path)) {
        return;
    }

    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        // Allow the hosting environment (or a local test process) to override
        // file-based values without rewriting the production .env file.
        if (!array_key_exists($key, $_ENV) && getenv($key) === false) {
            $_ENV[$key] = trim($value, " \t\n\r\0\x0B\"");
        }
    }
}

function env(string $key, ?string $default = null): ?string
{
    return $_ENV[$key] ?? getenv($key) ?: $default;
}

function jsonBody(): array
{
    $body = json_decode(rawBody() ?: '{}', true);
    if (!is_array($body)) {
        throw new HttpException(400, 'Request body must be valid JSON.');
    }
    return $body;
}

function rawBody(): string
{
    static $body = null;
    if ($body === null) {
        $body = file_get_contents('php://input') ?: '';
    }
    return $body;
}

function allowedOrigin(string $origin): bool
{
    if ($origin === '') {
        return false;
    }

    $parsed = parse_url($origin);
    $host = strtolower($parsed['host'] ?? '');
    $scheme = strtolower($parsed['scheme'] ?? '');

    if (env('APP_ENV') === 'development') {
        // Only allow known local development origins — never a blanket wildcard.
        // Covers browser dev servers, Flutter web, and emulator traffic.
        if (in_array($host, ['localhost', '127.0.0.1', '::1'], true)
            && in_array($scheme, ['http', 'https'], true)) {
            return true;
        }
        return false;
    }

    // Production: strictly validate against configured origins.
    $allowed = array_filter(array_map('trim', explode(',', (string) env('APP_ALLOWED_ORIGINS', ''))));
    return in_array($origin, $allowed, true);
}

function respond(int $status, array $payload): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function uuid(): string
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);
    return sprintf('%s-%s-%s-%s-%s', substr($hex, 0, 8), substr($hex, 8, 4), substr($hex, 12, 4), substr($hex, 16, 4), substr($hex, 20));
}

function clientIp(): ?string
{
    return $_SERVER['REMOTE_ADDR'] ?? null;
}

function userAgent(): ?string
{
    return isset($_SERVER['HTTP_USER_AGENT']) ? substr($_SERVER['HTTP_USER_AGENT'], 0, 255) : null;
}

function bearerToken(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(.+)$/i', $header, $matches)) {
        throw new HttpException(401, 'Missing bearer token.');
    }
    return trim($matches[1]);
}

function createOpaqueToken(): string
{
    return rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
}

function tokenHash(string $token): string
{
    return hash('sha256', $token);
}

/**
 * Validates and normalizes an HTTP(S) URL for shared scan-table lookups.
 * Scheme and a root trailing slash do not affect the lookup key.
 *
 * @return array{url:string, normalized_url:string, normalized_url_hash:string, hostname:string}
 */
function normalizeUrlInput(string $input): array
{
    $value = trim($input);
    if ($value === '' || strlen($value) > 2048) {
        throw new HttpException(422, 'A valid HTTP or HTTPS URL is required.');
    }
    if (!preg_match('#^https?://#i', $value)) {
        $value = 'https://' . $value;
    }
    if (!filter_var($value, FILTER_VALIDATE_URL)) {
        throw new HttpException(422, 'A valid HTTP or HTTPS URL is required.');
    }

    $parts = parse_url($value);
    $scheme = strtolower((string) ($parts['scheme'] ?? ''));
    $host = strtolower(rtrim((string) ($parts['host'] ?? ''), '.'));
    if (!in_array($scheme, ['http', 'https'], true) || $host === '' || strlen($host) > 255 || isset($parts['user']) || isset($parts['pass'])) {
        throw new HttpException(422, 'A valid HTTP or HTTPS URL is required.');
    }

    $port = isset($parts['port']) ? (int) $parts['port'] : null;
    $portPart = $port !== null && !(($scheme === 'http' && $port === 80) || ($scheme === 'https' && $port === 443))
        ? ':' . $port
        : '';
    $path = preg_replace('#/+#', '/', (string) ($parts['path'] ?? '')) ?: '';
    $path = $path === '/' ? '' : rtrim($path, '/');
    $query = isset($parts['query']) && $parts['query'] !== '' ? '?' . $parts['query'] : '';
    $normalized = strtolower($host . $portPart . $path . $query);

    return [
        'url' => $scheme . '://' . $host . $portPart . ($path === '' ? '' : $path) . $query,
        'normalized_url' => $normalized,
        'normalized_url_hash' => hash('sha256', $normalized),
        'hostname' => $host,
    ];
}

function validatePassword(string $password): void
{
    if (strlen($password) < 10 || !preg_match('/[A-Z]/', $password) || !preg_match('/[a-z]/', $password) || !preg_match('/\d/', $password)) {
        throw new HttpException(422, 'Password must be at least 10 characters and include upper-case, lower-case, and a number.');
    }
}

// ─── SSRF Protection ────────────────────────────────────────────────────────

/**
 * Returns true if the given IP address is in a private, reserved, or
 * otherwise internal range that must not be reached via user-supplied URLs.
 */
function isBlockedIp(string $ip): bool
{
    // Normalize IPv6-mapped IPv4 (e.g. ::ffff:127.0.0.1)
    if (preg_match('/^::ffff:(\d+\.\d+\.\d+\.\d+)$/i', $ip, $m)) {
        $ip = $m[1];
    }

    $blocked = [
        '127.0.0.0/8',       // Loopback
        '10.0.0.0/8',        // Private (Class A)
        '172.16.0.0/12',     // Private (Class B)
        '192.168.0.0/16',    // Private (Class C)
        '169.254.0.0/16',    // Link-local / cloud metadata
        '100.64.0.0/10',     // Carrier-grade NAT
        '0.0.0.0/8',         // "This" network
        '192.0.0.0/24',      // IETF protocol assignments
        '192.0.2.0/24',      // Documentation (TEST-NET-1)
        '198.51.100.0/24',   // Documentation (TEST-NET-2)
        '203.0.113.0/24',    // Documentation (TEST-NET-3)
        '224.0.0.0/4',       // Multicast
        '240.0.0.0/4',       // Reserved
        '255.255.255.255/32', // Broadcast
    ];

    $blockedIpv6 = ['::1', '::'];

    // IPv6 exact matches + prefix checks
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
        if (in_array($ip, $blockedIpv6, true)) {
            return true;
        }
        $packed = @inet_pton($ip);
        if ($packed === false) {
            return true; // Unparseable → block
        }
        $hex = bin2hex($packed);
        // fe80::/10 (link-local)
        if (str_starts_with($hex, 'fe8') || str_starts_with($hex, 'fe9')
            || str_starts_with($hex, 'fea') || str_starts_with($hex, 'feb')) {
            return true;
        }
        // fc00::/7 (unique-local)
        if (str_starts_with($hex, 'fc') || str_starts_with($hex, 'fd')) {
            return true;
        }
        return false;
    }

    // IPv4 CIDR matching
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return true; // Cannot parse → block
    }

    $ipLong = ip2long($ip);
    foreach ($blocked as $cidr) {
        [$subnet, $bits] = explode('/', $cidr);
        $mask = -1 << (32 - (int) $bits);
        if (($ipLong & $mask) === (ip2long($subnet) & $mask)) {
            return true;
        }
    }
    return false;
}

/**
 * Validates a URL for safe outbound requests (SSRF protection).
 * Returns the resolved IP if safe, or throws HttpException if blocked.
 */
function validateUrlForOutbound(string $url): string
{
    $parsed = parse_url($url);
    $scheme = strtolower($parsed['scheme'] ?? '');
    if (!in_array($scheme, ['http', 'https'], true)) {
        throw new HttpException(422, 'Only HTTP and HTTPS URLs are supported.');
    }

    $host = strtolower($parsed['host'] ?? '');
    if ($host === '' || strlen($host) > 255) {
        throw new HttpException(422, 'Invalid hostname.');
    }

    // Block obvious localhost aliases
    $blockedHosts = ['localhost', 'localhost.localdomain', '0.0.0.0', '127.0.0.1', '::1', '[::1]'];
    if (in_array($host, $blockedHosts, true)) {
        logSsrfAttempt($url, $host, 'Blocked hostname');
        throw new HttpException(422, 'This URL cannot be scanned.');
    }

    // Resolve DNS
    $ip = gethostbyname($host);
    if ($ip === $host) {
        // Resolution failed — try IPv6
        $records = @dns_get_record($host, DNS_AAAA);
        if (!empty($records)) {
            $ip = $records[0]['ipv6'] ?? $host;
        }
    }

    if ($ip === $host) {
        throw new HttpException(422, 'Unable to resolve hostname.');
    }

    if (isBlockedIp($ip)) {
        logSsrfAttempt($url, $ip, 'Blocked IP range');
        throw new HttpException(422, 'This URL cannot be scanned.');
    }

    return $ip;
}

// ─── Security Logging ───────────────────────────────────────────────────────

function logSsrfAttempt(string $url, string $resolvedIp, string $reason): void
{
    error_log(sprintf(
        '[SSRF-BLOCKED] %s | URL: %s | Resolved: %s | Reason: %s | IP: %s',
        gmdate('Y-m-d\TH:i:s\Z'),
        substr($url, 0, 500),
        $resolvedIp,
        $reason,
        clientIp() ?? 'unknown'
    ));
}

function logRejectedOrigin(string $origin, string $endpoint): void
{
    error_log(sprintf(
        '[CORS-REJECTED] %s | Origin: %s | Endpoint: %s | IP: %s',
        gmdate('Y-m-d\TH:i:s\Z'),
        substr($origin, 0, 200),
        $endpoint,
        clientIp() ?? 'unknown'
    ));
}
