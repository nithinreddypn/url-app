<?php
declare(strict_types=1);

/**
 * Verifies Google OpenID Connect ID tokens without trusting any profile data
 * supplied by the Flutter client. Google publishes the signing keys as JWKS;
 * the selected key is converted to PEM and checked with OpenSSL.
 */
final class GoogleIdTokenVerifier
{
    public function __construct(private readonly string $clientId)
    {
    }

    /**
     * @return array{sub:string,email:string,name:string}
     */
    public function verify(string $token): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }

        [$encodedHeader, $encodedClaims, $encodedSignature] = $parts;
        $header = $this->decodeJsonPart($encodedHeader);
        $claims = $this->decodeJsonPart($encodedClaims);
        $signature = $this->decodePart($encodedSignature);

        if (($header['alg'] ?? null) !== 'RS256' || !is_string($header['kid'] ?? null)) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }

        $key = $this->googleKey($header['kid']);
        $verified = openssl_verify(
            $encodedHeader . '.' . $encodedClaims,
            $signature,
            $this->jwkToPem($key),
            OPENSSL_ALGO_SHA256,
        );
        if ($verified !== 1) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }

        $issuer = $claims['iss'] ?? null;
        $audience = $claims['aud'] ?? null;
        $authorizedParty = $claims['azp'] ?? null;
        $email = strtolower(trim((string) ($claims['email'] ?? '')));
        $subject = trim((string) ($claims['sub'] ?? ''));
        $expiresAt = (int) ($claims['exp'] ?? 0);
        $emailVerified = $claims['email_verified'] ?? false;

        $audienceMatches = is_string($audience)
            ? hash_equals($this->clientId, $audience)
            : is_array($audience) && in_array($this->clientId, $audience, true);
        $authorizedPartyMatches = !is_array($audience)
            || (is_string($authorizedParty) && hash_equals($this->clientId, $authorizedParty));
        $isVerifiedEmail = $emailVerified === true || $emailVerified === 'true' || $emailVerified === 1 || $emailVerified === '1';

        if (!in_array($issuer, ['accounts.google.com', 'https://accounts.google.com'], true)
            || !$audienceMatches
            || !$authorizedPartyMatches
            || $expiresAt < time() - 60
            || $subject === ''
            || !filter_var($email, FILTER_VALIDATE_EMAIL)
            || !$isVerifiedEmail) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }

        $name = trim((string) ($claims['name'] ?? ''));
        return [
            'sub' => $subject,
            'email' => $email,
            'name' => $name !== '' ? $name : explode('@', $email)[0],
        ];
    }

    /** @return array<string,mixed> */
    private function googleKey(string $keyId): array
    {
        try {
            $response = HttpClient::request('GET', 'https://www.googleapis.com/oauth2/v3/certs');
        } catch (Throwable $error) {
            throw new HttpException(503, 'Google sign-in is temporarily unavailable.');
        }
        if ($response['status'] !== 200 || !is_array($response['body']['keys'] ?? null)) {
            throw new HttpException(503, 'Google sign-in is temporarily unavailable.');
        }
        foreach ($response['body']['keys'] as $key) {
            if (is_array($key) && ($key['kid'] ?? null) === $keyId && ($key['kty'] ?? null) === 'RSA') {
                return $key;
            }
        }
        throw new HttpException(401, 'Google sign-in could not be verified.');
    }

    /** @return array<string,mixed> */
    private function decodeJsonPart(string $part): array
    {
        $decoded = json_decode($this->decodePart($part), true);
        if (!is_array($decoded)) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }
        return $decoded;
    }

    private function decodePart(string $value): string
    {
        $remainder = strlen($value) % 4;
        if ($remainder > 0) {
            $value .= str_repeat('=', 4 - $remainder);
        }
        $decoded = base64_decode(strtr($value, '-_', '+/'), true);
        if ($decoded === false) {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }
        return $decoded;
    }

    /** @param array<string,mixed> $key */
    private function jwkToPem(array $key): string
    {
        $modulus = isset($key['n']) && is_string($key['n']) ? $this->decodePart($key['n']) : '';
        $exponent = isset($key['e']) && is_string($key['e']) ? $this->decodePart($key['e']) : '';
        if ($modulus === '' || $exponent === '') {
            throw new HttpException(401, 'Google sign-in could not be verified.');
        }

        $rsaPublicKey = $this->derSequence(
            $this->derInteger($modulus) . $this->derInteger($exponent),
        );
        $algorithm = hex2bin('300d06092a864886f70d0101010500');
        $subjectPublicKeyInfo = $this->derSequence(
            $algorithm . "\x03" . $this->derLength(strlen($rsaPublicKey) + 1) . "\x00" . $rsaPublicKey,
        );

        return "-----BEGIN PUBLIC KEY-----\n"
            . chunk_split(base64_encode($subjectPublicKeyInfo), 64, "\n")
            . "-----END PUBLIC KEY-----\n";
    }

    private function derInteger(string $value): string
    {
        if ((ord($value[0]) & 0x80) !== 0) {
            $value = "\x00" . $value;
        }
        return "\x02" . $this->derLength(strlen($value)) . $value;
    }

    private function derSequence(string $value): string
    {
        return "\x30" . $this->derLength(strlen($value)) . $value;
    }

    private function derLength(int $length): string
    {
        if ($length < 128) {
            return chr($length);
        }
        $encoded = '';
        while ($length > 0) {
            $encoded = chr($length & 0xff) . $encoded;
            $length >>= 8;
        }
        return chr(0x80 | strlen($encoded)) . $encoded;
    }
}
