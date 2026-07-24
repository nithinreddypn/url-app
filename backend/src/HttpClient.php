<?php
declare(strict_types=1);

final class HttpClient
{
    public static function request(string $method, string $url, array $headers = [], ?array $json = null, ?string $basicUser = null, ?string $basicPassword = null, ?array $form = null): array
    {
        if (!extension_loaded('curl')) {
            throw new RuntimeException('The PHP cURL extension is required.');
        }
        $handle = curl_init($url);
        $requestHeaders = array_merge(['Accept: application/json'], $headers);
        $options = [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_HTTPHEADER => $requestHeaders,
        ];
        if ($json !== null && $form !== null) {
            throw new InvalidArgumentException('Send either JSON or form data, not both.');
        }
        if ($json !== null) {
            $requestHeaders[] = 'Content-Type: application/json';
            $options[CURLOPT_HTTPHEADER] = $requestHeaders;
            $options[CURLOPT_POSTFIELDS] = json_encode($json, JSON_THROW_ON_ERROR);
        }
        if ($form !== null) {
            $requestHeaders[] = 'Content-Type: application/x-www-form-urlencoded';
            $options[CURLOPT_HTTPHEADER] = $requestHeaders;
            $options[CURLOPT_POSTFIELDS] = http_build_query($form, '', '&', PHP_QUERY_RFC3986);
        }
        if ($basicUser !== null) {
            $options[CURLOPT_USERPWD] = $basicUser . ':' . $basicPassword;
        }
        curl_setopt_array($handle, $options);
        $body = curl_exec($handle);
        if ($body === false) {
            throw new RuntimeException('HTTP request failed: ' . curl_error($handle));
        }
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        curl_close($handle);
        $decoded = json_decode($body, true);
        return ['status' => $status, 'body' => is_array($decoded) ? $decoded : [], 'raw' => $body];
    }
}
