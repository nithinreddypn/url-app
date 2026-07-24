<?php
declare(strict_types=1);

final class Mailer
{
    public function send(string $to, string $subject, string $text, ?string $html = null): void
    {
        $transport = env('MAIL_TRANSPORT', 'log');
        if ($transport === 'log') {
            $directory = dirname(__DIR__) . '/storage';
            if (!is_dir($directory)) {
                mkdir($directory, 0700, true);
            }
            file_put_contents($directory . '/mail.log', sprintf("[%s] To: %s\nSubject: %s\n%s\n\n", gmdate('c'), $to, $subject, $text), FILE_APPEND | LOCK_EX);
            return;
        }
        if ($transport === 'smtp') {
            $this->sendSmtp($to, $subject, $text, $html);
            return;
        }
        if ($transport === 'resend') {
            $key = env('RESEND_API_KEY');
            if ($key === null || $key === '') {
                throw new RuntimeException('RESEND_API_KEY is required when MAIL_TRANSPORT=resend.');
            }
            $payload = [
                'from' => $this->fromHeader(),
                'to' => [$to],
                'subject' => $subject,
                'text' => $text,
            ];
            if ($html !== null) {
                $payload['html'] = $html;
            }
            $response = HttpClient::request('POST', 'https://api.resend.com/emails', [
                'Authorization: Bearer ' . $key,
            ], $payload);
            if ($response['status'] < 200 || $response['status'] >= 300) {
                throw new RuntimeException('Email provider rejected the message.');
            }
            return;
        }
        if ($transport !== 'mail') {
            throw new RuntimeException('Unsupported mail transport. Use log, smtp, mail, or resend.');
        }
        [$contentType, $body] = $this->mimeContent($text, $html);
        $headers = [
            'From: ' . $this->fromHeader(),
            'MIME-Version: 1.0',
            'Content-Type: ' . $contentType,
        ];
        if (!mail($to, $subject, $body, implode("\r\n", $headers))) {
            throw new RuntimeException('Unable to deliver email.');
        }
    }

    private function sendSmtp(string $to, string $subject, string $text, ?string $html): void
    {
        $host = $this->required('SMTP_HOST');
        $port = (int) env('SMTP_PORT', '465');
        $username = $this->required('SMTP_USERNAME');
        $password = $this->required('SMTP_PASSWORD');
        $encryption = strtolower((string) env('SMTP_ENCRYPTION', 'ssl'));
        if (!in_array($encryption, ['ssl', 'tls', 'starttls'], true) || $port < 1 || $port > 65535) {
            throw new RuntimeException('SMTP encryption or port is invalid.');
        }

        $target = ($encryption === 'ssl' ? 'ssl://' : 'tcp://') . $host . ':' . $port;
        $context = stream_context_create([
            'ssl' => [
                'verify_peer' => false,
                'verify_peer_name' => false,
                'allow_self_signed' => true,
            ]
        ]);
        $socket = @stream_socket_client($target, $errno, $error, 5, STREAM_CLIENT_CONNECT, $context);
        if (!is_resource($socket)) {
            throw new RuntimeException("Unable to connect to SMTP server: {$error} ({$errno}).");
        }
        stream_set_timeout($socket, 5);
        try {
            $this->expect($socket, [220]);
            $this->command($socket, 'EHLO ' . $this->heloName(), [250]);
            if ($encryption !== 'ssl') {
                $this->command($socket, 'STARTTLS', [220]);
                if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
                    throw new RuntimeException('Unable to enable SMTP TLS encryption.');
                }
                $this->command($socket, 'EHLO ' . $this->heloName(), [250]);
            }
            $this->command($socket, 'AUTH LOGIN', [334]);
            $this->command($socket, base64_encode($username), [334]);
            $this->command($socket, base64_encode($password), [235]);
            $from = $this->fromAddress();
            $this->command($socket, "MAIL FROM:<{$from}>", [250]);
            $this->command($socket, "RCPT TO:<{$to}>", [250, 251]);
            $this->command($socket, 'DATA', [354]);
            [$contentType, $body] = $this->mimeContent($text, $html);
            $message = implode("\r\n", [
                'From: ' . $this->fromHeader(),
                'To: ' . $this->cleanHeader($to),
                'Subject: ' . $this->cleanHeader($subject),
                'MIME-Version: 1.0',
                'Content-Type: ' . $contentType,
                '',
                $this->dotStuff($body),
                '.',
                '',
            ]);
            fwrite($socket, $message);
            $this->expect($socket, [250]);
            $this->command($socket, 'QUIT', [221]);
        } finally {
            fclose($socket);
        }
    }

    private function command($socket, string $command, array $codes): void
    {
        fwrite($socket, $command . "\r\n");
        $this->expect($socket, $codes);
    }

    private function expect($socket, array $codes): void
    {
        $response = '';
        do {
            $line = fgets($socket, 515);
            if ($line === false) {
                throw new RuntimeException('SMTP server closed the connection unexpectedly.');
            }
            $response .= $line;
        } while (preg_match('/^\d{3}-/', $line));
        $code = (int) substr($response, 0, 3);
        if (!in_array($code, $codes, true)) {
            throw new RuntimeException('SMTP server rejected the request: ' . trim($response));
        }
    }

    private function required(string $key): string
    {
        $value = env($key);
        if ($value === null || $value === '') {
            throw new RuntimeException("{$key} is required when MAIL_TRANSPORT=smtp.");
        }
        return $value;
    }

    private function fromAddress(): string
    {
        $address = $this->required('MAIL_FROM');
        if (!filter_var($address, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException('MAIL_FROM must be a valid email address.');
        }
        return $address;
    }

    private function fromHeader(): string
    {
        return $this->cleanHeader((string) env('MAIL_FROM_NAME', 'URL Defender')) . ' <' . $this->fromAddress() . '>';
    }

    private function cleanHeader(string $value): string
    {
        return str_replace(["\r", "\n"], '', $value);
    }

    private function dotStuff(string $text): string
    {
        $normalized = str_replace(["\r\n", "\r"], "\n", $text);
        $stuffed = preg_replace('/^\./m', '..', $normalized) ?? $normalized;
        return str_replace("\n", "\r\n", $stuffed);
    }

    /** @return array{0: string, 1: string} */
    private function mimeContent(string $text, ?string $html): array
    {
        if ($html === null) {
            return ['text/plain; charset=UTF-8', $text];
        }

        $boundary = 'url-defender-' . bin2hex(random_bytes(18));
        $body = implode("\r\n", [
            '--' . $boundary,
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
            '',
            $text,
            '--' . $boundary,
            'Content-Type: text/html; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
            '',
            $html,
            '--' . $boundary . '--',
        ]);

        return ['multipart/alternative; boundary="' . $boundary . '"', $body];
    }

    private function heloName(): string
    {
        return preg_replace('/[^a-zA-Z0-9.-]/', '', gethostname() ?: 'localhost') ?: 'localhost';
    }

    public function getTemplate(string $heading, string $bodyText, string $extraHtml = ''): string
    {
        return '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #FFFFFF;
      color: #0F172A;
      margin: 0;
      padding: 0;
    }
    .wrapper {
      width: 100%;
      background-color: #FFFFFF;
      padding: 40px 0;
    }
    .container {
      max-width: 580px;
      margin: 0 auto;
      background-color: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.03);
    }
    .header {
      background-color: #F1F5F9;
      padding: 24px;
      text-align: center;
      border-bottom: 1px solid #E2E8F0;
    }
    .header img {
      height: 38px;
      vertical-align: middle;
      margin-right: 8px;
    }
    .header span {
      color: #0F172A;
      font-size: 20px;
      font-weight: 700;
      letter-spacing: 0.5px;
      vertical-align: middle;
      text-transform: uppercase;
    }
    .content {
      padding: 40px 30px;
      line-height: 1.6;
    }
    .welcome-text {
      color: #475569;
      font-size: 14px;
      margin-bottom: 20px;
    }
    .footer {
      background-color: #F1F5F9;
      padding: 24px;
      text-align: center;
      font-size: 12px;
      color: #6B7280;
      border-top: 1px solid #E2E8F0;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <img src="http://localhost:8123/images/logo.png" alt="URL Defender">
        <span>URL Defender</span>
      </div>
      <div class="content">
        <p class="welcome-text">Hello,</p>
        <p style="font-size: 16px; color: #0F172A; margin-bottom: 16px; font-weight: 600;">' . htmlspecialchars($heading) . '</p>
        <p style="font-size: 14px; color: #475569; margin-bottom: 24px;">' . htmlspecialchars($bodyText) . '</p>
        ' . $extraHtml . '
        <p style="font-size: 12px; color: #94A3B8; margin-top: 30px; border-top: 1px solid #E2E8F0; padding-top: 20px;">If you did not request this email, you can safely ignore it.</p>
      </div>
      <div class="footer">
        <p>&copy; ' . date('Y') . ' URL Defender. All rights reserved.</p>
      </div>
    </div>
  </div>
</body>
</html>';
    }
}
