<?php
/**
 * Security Regression Test — CORS & SSRF Protection
 *
 * Run: php scratch/security_test.php
 * Requires: Support.php loaded (for isBlockedIp, validateUrlForOutbound, allowedOrigin)
 */
require __DIR__ . '/../backend/src/Support.php';
loadEnv(__DIR__ . '/../backend/.env');

$pass = 0;
$fail = 0;

function assertResult(bool $condition, string $description): void
{
    global $pass, $fail;
    if ($condition) {
        echo "  ✅ PASS: $description\n";
        $pass++;
    } else {
        echo "  ❌ FAIL: $description\n";
        $fail++;
    }
}

echo "\n" . str_repeat('═', 60) . "\n";
echo "  URL Defender — Security Regression Tests\n";
echo str_repeat('═', 60) . "\n\n";

// ─── CORS Tests ─────────────────────────────────────────────────────────────

echo "── CORS Origin Validation ──\n\n";

// Force development mode for testing
$_ENV['APP_ENV'] = 'development';

assertResult(
    allowedOrigin('http://localhost') === true,
    'Dev: http://localhost allowed'
);
assertResult(
    allowedOrigin('http://localhost:3000') === true,
    'Dev: http://localhost:3000 allowed'
);
assertResult(
    allowedOrigin('http://localhost:5173') === true,
    'Dev: http://localhost:5173 allowed'
);
assertResult(
    allowedOrigin('http://127.0.0.1') === true,
    'Dev: http://127.0.0.1 allowed'
);
assertResult(
    allowedOrigin('http://127.0.0.1:8080') === true,
    'Dev: http://127.0.0.1:8080 allowed'
);
assertResult(
    allowedOrigin('https://localhost') === true,
    'Dev: https://localhost allowed'
);

// These MUST be rejected even in dev mode
assertResult(
    allowedOrigin('https://evil.com') === false,
    'Dev: https://evil.com REJECTED'
);
assertResult(
    allowedOrigin('https://attacker.local') === false,
    'Dev: https://attacker.local REJECTED'
);
assertResult(
    allowedOrigin('http://malicious-site.com') === false,
    'Dev: http://malicious-site.com REJECTED'
);
assertResult(
    allowedOrigin('') === false,
    'Dev: empty origin REJECTED'
);
assertResult(
    allowedOrigin('javascript:alert(1)') === false,
    'Dev: javascript: URI REJECTED'
);

// Production mode
$_ENV['APP_ENV'] = 'production';
$_ENV['APP_ALLOWED_ORIGINS'] = 'https://urldefender.com,https://app.urldefender.com';

assertResult(
    allowedOrigin('https://urldefender.com') === true,
    'Prod: configured origin allowed'
);
assertResult(
    allowedOrigin('https://app.urldefender.com') === true,
    'Prod: configured subdomain allowed'
);
assertResult(
    allowedOrigin('https://evil.com') === false,
    'Prod: unknown origin REJECTED'
);
assertResult(
    allowedOrigin('http://localhost') === false,
    'Prod: localhost REJECTED'
);
assertResult(
    allowedOrigin('https://urldefender.com.evil.com') === false,
    'Prod: subdomain spoof REJECTED'
);

// Reset
$_ENV['APP_ENV'] = 'development';

echo "\n── SSRF IP Blocking ──\n\n";

// ─── SSRF Tests ─────────────────────────────────────────────────────────────

// Blocked IPs
$blockedIps = [
    '127.0.0.1'       => 'Loopback',
    '127.0.0.2'       => 'Loopback range',
    '10.0.0.1'        => 'Private 10.x',
    '10.255.255.255'  => 'Private 10.x max',
    '172.16.0.1'      => 'Private 172.16.x',
    '172.31.255.255'  => 'Private 172.31.x max',
    '192.168.0.1'     => 'Private 192.168.x',
    '192.168.1.100'   => 'Private 192.168.x',
    '169.254.169.254' => 'Cloud metadata',
    '169.254.0.1'     => 'Link-local',
    '100.64.0.1'      => 'Carrier NAT',
    '0.0.0.0'         => 'This network',
    '224.0.0.1'       => 'Multicast',
    '240.0.0.1'       => 'Reserved',
    '255.255.255.255' => 'Broadcast',
    '192.0.2.1'       => 'TEST-NET-1',
    '198.51.100.1'    => 'TEST-NET-2',
    '203.0.113.1'     => 'TEST-NET-3',
];

foreach ($blockedIps as $ip => $label) {
    assertResult(
        isBlockedIp($ip) === true,
        "Blocked: $ip ($label)"
    );
}

// IPv6 blocked
assertResult(isBlockedIp('::1') === true, 'Blocked: ::1 (IPv6 loopback)');
assertResult(isBlockedIp('::') === true, 'Blocked: :: (IPv6 unspecified)');

// Allowed IPs (public internet)
$allowedIps = [
    '8.8.8.8'        => 'Google DNS',
    '1.1.1.1'        => 'Cloudflare DNS',
    '142.250.195.14' => 'Google',
    '20.27.177.113'  => 'Microsoft',
    '185.199.108.153' => 'GitHub Pages',
];

foreach ($allowedIps as $ip => $label) {
    assertResult(
        isBlockedIp($ip) === false,
        "Allowed: $ip ($label)"
    );
}

echo "\n── SSRF URL Validation ──\n\n";

// Blocked URLs (hostname-level)
$blockedUrls = [
    'http://localhost/'               => 'localhost',
    'http://127.0.0.1/'               => '127.0.0.1',
    'http://0.0.0.0/'                 => '0.0.0.0',
    'http://[::1]/'                   => 'IPv6 loopback',
    'file:///etc/passwd'              => 'file:// protocol',
    'ftp://evil.com/'                 => 'ftp:// protocol',
    'gopher://evil.com/'              => 'gopher:// protocol',
    'data://text/plain;base64,SGVsbG8=' => 'data:// protocol',
    'ldap://evil.com/'                => 'ldap:// protocol',
    'ssh://evil.com/'                 => 'ssh:// protocol',
];

foreach ($blockedUrls as $url => $label) {
    $blocked = false;
    try {
        validateUrlForOutbound($url);
    } catch (HttpException $e) {
        $blocked = true;
    }
    assertResult($blocked === true, "URL blocked: $url ($label)");
}

// Allowed URLs (should not throw)
$safeUrls = [
    'https://google.com'   => 'Google',
    'https://github.com'   => 'GitHub',
    'https://microsoft.com' => 'Microsoft',
];

foreach ($safeUrls as $url => $label) {
    $allowed = false;
    try {
        validateUrlForOutbound($url);
        $allowed = true;
    } catch (HttpException $e) {
        // Might fail if DNS doesn't resolve in test env — that's OK
        if (strpos($e->getMessage(), 'Unable to resolve') !== false) {
            $allowed = true; // DNS resolution failure is not an SSRF block
        }
    }
    assertResult($allowed === true, "URL allowed: $url ($label)");
}

echo "\n" . str_repeat('═', 60) . "\n";
echo "  Results: $pass passed, $fail failed\n";
echo str_repeat('═', 60) . "\n\n";

exit($fail > 0 ? 1 : 0);
