<?php
declare(strict_types=1);

final class AuthController
{
    public function __construct(private readonly PDO $db, private readonly Mailer $mailer)
    {
    }

    public function register(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $fullName = trim((string) ($input['full_name'] ?? ''));
        $password = (string) ($input['password'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 191 || $fullName === '' || strlen($fullName) > 120) {
            throw new HttpException(422, 'A valid email and full name are required.');
        }
        validatePassword($password);

        $this->db->beginTransaction();
        try {
            $exists = $this->db->prepare('SELECT id FROM users WHERE email = ? LIMIT 1 FOR UPDATE');
            $exists->execute([$email]);
            if ($exists->fetch()) {
                throw new HttpException(409, 'An account already exists for this email.');
            }

            $userId = uuid();
            $this->db->prepare('INSERT INTO users (id, email, password_hash, full_name) VALUES (?, ?, ?, ?)')
                ->execute([$userId, $email, password_hash($password, PASSWORD_ARGON2ID), $fullName]);
            $this->db->prepare("INSERT INTO user_roles (id, user_id, role) VALUES (?, ?, 'user')")
                ->execute([uuid(), $userId]);

            $otp = (string) random_int(100000, 999999);
            $this->db->prepare('INSERT INTO email_verifications (id, user_id, code_hash, expires_at) VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 MINUTE))')
                ->execute([uuid(), $userId, password_hash($otp, PASSWORD_ARGON2ID)]);
            $this->audit($userId, 'auth.registered', ['email' => $email]);
            $this->db->commit();
            try {
                $subject = 'Verify your URL Defender account';
                $text = "Your verification code is {$otp}. It expires in 5 minutes.";
                
                $extraHtml = '<div style="background-color: #1F2937; border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
                    <p style="font-family: \'Courier New\', Courier, monospace; font-size: 38px; font-weight: 700; color: #22C55E; letter-spacing: 6px; margin: 0;">' . $otp . '</p>
                    <p style="color: #EF4444; font-size: 13px; font-weight: 600; margin-top: 12px; margin-bottom: 0;">It expires in 5 minutes.</p>
                </div>';
                
                $html = $this->mailer->getTemplate('Verify your email address', 'Please use the verification code below to verify your URL Defender account.', $extraHtml);
                
                $this->mailer->send($email, $subject, $text, $html);
            } catch (Throwable $mailError) {
                error_log('Verification email failed: ' . $mailError->getMessage());
            }
            return ['message' => 'Account created. Check your email for the verification code.', 'user_id' => $userId];
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function verifyEmail(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $code = trim((string) ($input['code'] ?? ''));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !preg_match('/^\d{6}$/', $code)) {
            throw new HttpException(422, 'A valid email and six-digit code are required.');
        }

        $this->db->beginTransaction();
        try {
            $userStatement = $this->db->prepare(
                'SELECT id, email_verified_at
                 FROM users
                 WHERE email = ? AND deleted_at IS NULL
                 LIMIT 1
                 FOR UPDATE'
            );
            $userStatement->execute([$email]);
            $user = $userStatement->fetch();
            if ($user && $user['email_verified_at'] !== null) {
                $this->db->commit();
                return ['message' => 'Email verified. You can now sign in.'];
            }

            $stmt = $this->db->prepare(
                'SELECT ev.*, (ev.expires_at <= UTC_TIMESTAMP()) AS is_expired
                 FROM email_verifications ev
                 WHERE ev.user_id = ? AND ev.consumed_at IS NULL
                 ORDER BY ev.created_at DESC
                 LIMIT 1
                 FOR UPDATE'
            );
            $stmt->execute([$user['id'] ?? '']);
            $verification = $stmt->fetch();
            if (!$verification || (bool) $verification['is_expired'] || (int) $verification['attempts'] >= 5) {
                throw new HttpException(400, 'Verification code is invalid or expired.');
            }

            if (!password_verify($code, $verification['code_hash'])) {
                $this->db->prepare('UPDATE email_verifications SET attempts = attempts + 1 WHERE id = ?')->execute([$verification['id']]);
                // Preserve the failed-attempt counter before returning the
                // validation error; otherwise the surrounding rollback would
                // undo the rate-limit update.
                $this->db->commit();
                throw new HttpException(400, 'Verification code is invalid or expired.');
            }

            $this->db->prepare('UPDATE email_verifications SET consumed_at = UTC_TIMESTAMP(), verified_ip = ?, verified_user_agent = ? WHERE id = ?')
                ->execute([clientIp(), userAgent(), $verification['id']]);
            $this->db->prepare('UPDATE users SET email_verified_at = UTC_TIMESTAMP() WHERE id = ?')->execute([$user['id']]);
            $this->audit($user['id'], 'auth.email_verified');
            $this->db->commit();
            return ['message' => 'Email verified. You can now sign in.'];
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function resendVerification(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new HttpException(422, 'A valid email is required.');
        }
        $stmt = $this->db->prepare('SELECT id, email_verified_at FROM users WHERE email = ? AND deleted_at IS NULL AND is_active = 1 LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if (!$user || $user['email_verified_at'] !== null) {
            return ['message' => 'If the account requires verification, a new code has been sent.'];
        }
        $recent = $this->db->prepare('SELECT COUNT(*) FROM email_verifications WHERE user_id = ? AND created_at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL 10 MINUTE)');
        $recent->execute([$user['id']]);
        if ((int) $recent->fetchColumn() >= 3) {
            throw new HttpException(429, 'Too many verification requests. Try again later.');
        }
        $otp = (string) random_int(100000, 999999);
        $this->db->prepare('INSERT INTO email_verifications (id, user_id, code_hash, expires_at) VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 MINUTE))')
            ->execute([uuid(), $user['id'], password_hash($otp, PASSWORD_ARGON2ID)]);
        $this->audit($user['id'], 'auth.verification_resent');
        try {
            $subject = 'Your new URL Defender verification code';
            $text = "Your verification code is {$otp}. It expires in 5 minutes.";
            
            $extraHtml = '<div style="background-color: #1F2937; border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
                <p style="font-family: \'Courier New\', Courier, monospace; font-size: 38px; font-weight: 700; color: #22C55E; letter-spacing: 6px; margin: 0;">' . $otp . '</p>
                <p style="color: #EF4444; font-size: 13px; font-weight: 600; margin-top: 12px; margin-bottom: 0;">It expires in 5 minutes.</p>
            </div>';
            
            $html = $this->mailer->getTemplate('New verification code requested', 'Please use the verification code below to verify your URL Defender account.', $extraHtml);
            
            $this->mailer->send($email, $subject, $text, $html);
        } catch (Throwable $mailError) {
            error_log('Verification resend failed: ' . $mailError->getMessage());
        }
        return ['message' => 'If the account requires verification, a new code has been sent.'];
    }

    public function login(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $password === '') {
            throw new HttpException(422, 'Email and password are required.');
        }
        $this->assertLoginNotRateLimited($email);

        $stmt = $this->db->prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            $this->logLoginAttempt($email, $user['id'] ?? null, false, $user ? 'bad_password' : 'no_user');
            throw new HttpException(401, 'Invalid email or password.');
        }
        if (!(bool) $user['is_active']) {
            $this->logLoginAttempt($email, $user['id'], false, 'account_disabled');
            throw new HttpException(403, 'Your account has been disabled. Please contact support.');
        }
        if ($user['email_verified_at'] === null) {
            $this->logLoginAttempt($email, $user['id'], false, 'email_unverified');
            throw new HttpException(403, 'Verify your email before signing in.');
        }

        $token = createOpaqueToken();
        $this->db->prepare('INSERT INTO auth_sessions (id, user_id, token_hash, ip_address, user_agent, expires_at) VALUES (?, ?, ?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))')
            ->execute([uuid(), $user['id'], tokenHash($token), clientIp(), userAgent()]);
        $this->db->prepare('UPDATE users SET last_login_at = UTC_TIMESTAMP() WHERE id = ?')->execute([$user['id']]);
        $this->logLoginAttempt($email, $user['id'], true, null);
        $this->audit($user['id'], 'auth.logged_in');

        return ['token' => $token, 'token_type' => 'Bearer', 'expires_in' => 2592000, 'user' => $this->publicUser($user)];
    }

    /**
     * Creates a normal URL Defender session from a Google-issued ID token.
     * The client never supplies an email, name, or user ID that is trusted.
     */
    public function googleLogin(array $input): array
    {
        $idToken = trim((string) ($input['id_token'] ?? ''));
        $clientId = trim((string) env('GOOGLE_OAUTH_WEB_CLIENT_ID', ''));
        if ($idToken === '' || strlen($idToken) > 10000) {
            throw new HttpException(422, 'Google sign-in could not be completed.');
        }
        if ($clientId === '') {
            throw new HttpException(503, 'Google sign-in is temporarily unavailable.');
        }

        $googleUser = (new GoogleIdTokenVerifier($clientId))->verify($idToken);
        $email = $googleUser['email'];

        $this->db->beginTransaction();
        try {
            $existing = $this->db->prepare('SELECT * FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1 FOR UPDATE');
            $existing->execute([$email]);
            $user = $existing->fetch();

            if (!$user) {
                $this->db->commit();
                
                $expires = time() + 900; // 15 minutes
                $fullName = substr(trim($googleUser['name']), 0, 120);
                $tokenData = json_encode([
                    'email' => $email,
                    'name' => $fullName === '' ? explode('@', $email)[0] : $fullName,
                    'expires' => $expires
                ]);
                $signature = hash_hmac('sha256', $tokenData, env('GOOGLE_OAUTH_CLIENT_SECRET', 'url_defender_secret'));
                $baseUrl = rtrim((string) env('APP_URL', 'http://localhost:8123/api/v1'), '/');
                if (strpos($baseUrl, 'index.php') === false && strpos($baseUrl, 'localhost') === false && strpos($baseUrl, '127.0.0.1') === false) {
                    $baseUrl .= '/index.php';
                }
                $link = $baseUrl . "/auth/confirm-email?data=" . urlencode(base64_encode($tokenData)) . "&signature=" . urlencode($signature);
                
                try {
                    $subject = 'Confirm your URL Defender registration';
                    $text = "Please verify your email address by opening this link: " . $link;
                    
                    $extraHtml = '<div style="text-align: center; margin: 32px 0;">
                        <a href="' . $link . '" style="background-color: #16A34A; color: white; padding: 14px 30px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 15px; display: inline-block; box-shadow: 0 4px 6px rgba(22,163,74,0.15);">' . 'Confirm Email Address' . '</a>
                    </div>';
                    
                    $html = $this->mailer->getTemplate(
                        'Confirm your Google registration',
                        'Please click the button below to confirm your URL Defender registration and verify your account.',
                        $extraHtml
                    );
                    $this->mailer->send($email, $subject, $text, $html);
                } catch (Throwable $mailError) {
                    error_log('Google welcome email failed: ' . $mailError->getMessage());
                }
                return [
                    'verification_pending' => true,
                    'message' => 'A verification link has been sent to your email. Please click it to verify your account.'
                ];
            } else {
                if ($user['email_verified_at'] === null) {
                    $expires = time() + 900;
                    $tokenData = json_encode([
                        'email' => $email,
                        'name' => $user['full_name'],
                        'expires' => $expires
                    ]);
                    $signature = hash_hmac('sha256', $tokenData, env('GOOGLE_OAUTH_CLIENT_SECRET', 'url_defender_secret'));
                    $baseUrl = rtrim((string) env('APP_URL', 'http://localhost:8123/api/v1'), '/');
                    if (strpos($baseUrl, 'index.php') === false && strpos($baseUrl, 'localhost') === false && strpos($baseUrl, '127.0.0.1') === false) {
                        $baseUrl .= '/index.php';
                    }
                    $link = $baseUrl . "/auth/confirm-email?data=" . urlencode(base64_encode($tokenData)) . "&signature=" . urlencode($signature);
                    
                    $this->db->commit();
                    try {
                        $subject = 'Confirm your URL Defender registration';
                        $text = "Please verify your email address by opening this link: " . $link;
                        
                        $extraHtml = '<div style="text-align: center; margin: 32px 0;">
                            <a href="' . $link . '" style="background-color: #16A34A; color: white; padding: 14px 30px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 15px; display: inline-block; box-shadow: 0 4px 6px rgba(22,163,74,0.15);">' . 'Confirm Email Address' . '</a>
                        </div>';
                        
                        $html = $this->mailer->getTemplate(
                            'Confirm your Google registration',
                            'Please click the button below to confirm your URL Defender registration and verify your account.',
                            $extraHtml
                        );
                        $this->mailer->send($email, $subject, $text, $html);
                    } catch (Throwable $mailError) {
                        error_log('Google welcome email failed: ' . $mailError->getMessage());
                    }
                    return [
                        'verification_pending' => true,
                        'message' => 'Your email is not verified yet. A verification link has been sent to your email.'
                    ];
                }
                
                if (!(bool) $user['is_active']) {
                    throw new HttpException(403, 'Your account has been disabled. Please contact support.');
                }
                
                $this->db->prepare('UPDATE users SET last_login_at = UTC_TIMESTAMP() WHERE id = ?')
                    ->execute([$user['id']]);
            }

            $token = createOpaqueToken();
            $this->db->prepare('INSERT INTO auth_sessions (id, user_id, token_hash, ip_address, user_agent, expires_at) VALUES (?, ?, ?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))')
                ->execute([uuid(), $user['id'], tokenHash($token), clientIp(), userAgent()]);
            $this->audit($user['id'], 'auth.google_logged_in', ['provider' => 'google']);
            $this->db->commit();

            return [
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => 2592000,
                'user' => $this->publicUser($user),
            ];
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function logout(array $session): array
    {
        $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE id = ? AND revoked_at IS NULL')->execute([$session['session_id']]);
        $this->audit($session['id'], 'auth.logged_out');
        return ['message' => 'Signed out.'];
    }

    public function forgotPassword(array $input): array
    {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new HttpException(422, 'A valid email is required.');
        }
        $stmt = $this->db->prepare('SELECT id FROM users WHERE email = ? AND deleted_at IS NULL AND is_active = 1 LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if ($user) {
            $token = createOpaqueToken();
            $this->db->prepare('DELETE FROM password_resets WHERE user_id = ? AND consumed_at IS NULL')->execute([$user['id']]);
            $this->db->prepare('INSERT INTO password_resets (id, user_id, token_hash, expires_at, requested_ip, requested_user_agent) VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 MINUTE), ?, ?)')
                ->execute([uuid(), $user['id'], tokenHash($token), clientIp(), userAgent()]);
            $this->audit($user['id'], 'auth.password_reset_requested');
            $separator = str_contains((string) env('PASSWORD_RESET_URL', ''), '?') ? '&' : '?';
            $url = (string) env('PASSWORD_RESET_URL', env('APP_URL', '')) . $separator . 'token=' . rawurlencode($token);
            try {
                $safeUrl = htmlspecialchars($url, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                $html = <<<HTML
<!doctype html>
<html lang="en">
<body style="margin:0;padding:24px;background:#f8fafc;font-family:Arial,sans-serif;color:#111827">
  <div style="max-width:520px;margin:0 auto;padding:32px;background:#ffffff;border:1px solid #e5e7eb;border-radius:18px">
    <h1 style="margin:0 0 12px;font-size:24px">Reset your password</h1>
    <p style="margin:0 0 24px;color:#6b7280;line-height:1.6">Use the button below to reset your URL Defender password. This link expires in 30 minutes.</p>
    <a href="{$safeUrl}" style="display:inline-block;padding:14px 22px;border-radius:12px;background:#16a34a;color:#ffffff;text-decoration:none;font-weight:700">Reset Password</a>
    <p style="margin:24px 0 0;color:#6b7280;font-size:13px">If you did not request this change, you can safely ignore this email.</p>
  </div>
</body>
</html>
HTML;
                $this->mailer->send(
                    $email,
                    'Reset your URL Defender password',
                    "Reset your URL Defender password using the secure link below. It expires in 30 minutes:\n{$url}",
                    $html,
                );
            } catch (Throwable $mailError) {
                error_log('Password-reset email failed: ' . $mailError->getMessage());
            }
        }
        return ['message' => 'If the account exists, a password reset link has been sent.'];
    }

    public function resetPassword(array $input): array
    {
        $token = trim((string) ($input['token'] ?? ''));
        $password = (string) ($input['password'] ?? '');
        if ($token === '') {
            throw new HttpException(422, 'A reset token is required.');
        }
        validatePassword($password);

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare('SELECT * FROM password_resets WHERE token_hash = ? AND consumed_at IS NULL AND expires_at > UTC_TIMESTAMP() LIMIT 1 FOR UPDATE');
            $stmt->execute([tokenHash($token)]);
            $reset = $stmt->fetch();
            if (!$reset) {
                throw new HttpException(400, 'Reset token is invalid or expired.');
            }
            $this->db->prepare('UPDATE users SET password_hash = ? WHERE id = ?')->execute([password_hash($password, PASSWORD_ARGON2ID), $reset['user_id']]);
            $this->db->prepare('UPDATE password_resets SET consumed_at = UTC_TIMESTAMP() WHERE id = ?')->execute([$reset['id']]);
            $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND revoked_at IS NULL')->execute([$reset['user_id']]);
            $this->audit($reset['user_id'], 'auth.password_reset');
            $this->db->commit();
            return ['message' => 'Password updated. Sign in with your new password.'];
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function changePassword(array $session, array $input): array
    {
        $currentPassword = (string) ($input['current_password'] ?? '');
        $newPassword = (string) ($input['new_password'] ?? '');
        if ($currentPassword === '') {
            throw new HttpException(422, 'Current password is required.');
        }
        validatePassword($newPassword);
        $this->db->beginTransaction();
        try {
            $user = $this->db->prepare('SELECT password_hash FROM users WHERE id = ? LIMIT 1 FOR UPDATE');
            $user->execute([$session['id']]);
            $passwordHash = $user->fetchColumn();
            if (!is_string($passwordHash) || !password_verify($currentPassword, $passwordHash)) {
                throw new HttpException(422, 'Current password is incorrect.');
            }
            if (password_verify($newPassword, $passwordHash)) {
                throw new HttpException(422, 'New password must be different from the current password.');
            }
            $this->db->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
                ->execute([password_hash($newPassword, PASSWORD_ARGON2ID), $session['id']]);
            $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND id != ? AND revoked_at IS NULL')
                ->execute([$session['id'], $session['session_id']]);
            $this->db->prepare(
                "INSERT INTO notifications (id, user_id, type, title, message, severity)
                 VALUES (?, ?, 'security', 'Password changed', 'Your account password was changed successfully.', 'info')"
            )->execute([uuid(), $session['id']]);
            $this->audit($session['id'], 'auth.password_changed');
            $this->db->commit();
            return ['message' => 'Password changed successfully.'];
        } catch (Throwable $error) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            throw $error;
        }
    }

    public function currentUser(): array
    {
        $token = bearerToken();
        $stmt = $this->db->prepare('SELECT u.id, u.email, u.full_name, u.avatar_url, u.plan, u.email_verified_at, u.is_active, s.id AS session_id, s.expires_at FROM auth_sessions s INNER JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP() AND u.deleted_at IS NULL AND u.is_active = 1 LIMIT 1');
        $stmt->execute([tokenHash($token)]);
        $session = $stmt->fetch();
        if (!$session) {
            throw new HttpException(401, 'Session is invalid or expired.');
        }
        $session['avatar_url'] = $this->resolvedAvatarUrl($session['avatar_url'] ?? null);
        return $session;
    }

    public function updateProfile(array $session, array $input): array
    {
        $fullName = trim((string) ($input['full_name'] ?? ''));
        $avatarProvided = array_key_exists('avatar_url', $input);
        $avatarUrl = $avatarProvided ? $input['avatar_url'] : null;
        $allowedAvatars = ['icon:shield', 'icon:person', 'icon:bolt', 'icon:star', 'icon:security', 'icon:rocket'];
        if ($fullName === '' || strlen($fullName) > 120) {
            throw new HttpException(422, 'A display name of up to 120 characters is required.');
        }
        $uploadedPrefix = rtrim((string) env('APP_URL', ''), '/') . '/uploads/avatars/';
        $managedAvatarPath = $this->managedAvatarPath($avatarUrl);
        $isManagedAvatar = is_string($avatarUrl)
            && ($managedAvatarPath !== null)
            && (str_starts_with($avatarUrl, '/uploads/avatars/') || str_starts_with($avatarUrl, $uploadedPrefix));
        if ($avatarProvided && $avatarUrl !== null && (!is_string($avatarUrl) || (!in_array($avatarUrl, $allowedAvatars, true) && !$isManagedAvatar))) {
            throw new HttpException(422, 'The profile image is invalid.');
        }
        if ($avatarProvided) {
            $storedAvatar = $managedAvatarPath ?? $avatarUrl;
            $this->db->prepare('UPDATE users SET full_name = ?, avatar_url = ? WHERE id = ?')->execute([$fullName, $storedAvatar, $session['id']]);
        } else {
            $this->db->prepare('UPDATE users SET full_name = ? WHERE id = ?')->execute([$fullName, $session['id']]);
        }
        $this->audit($session['id'], 'profile.updated');
        return ['user' => $this->profileUser($session['id'])];
    }

    public function uploadAvatar(array $session): array
    {
        $file = $_FILES['image'] ?? null;
        if (!is_array($file)) {
            throw new HttpException(422, 'Select an image to upload.');
        }
        $uploadError = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if (in_array($uploadError, [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
            throw new HttpException(422, 'Profile images must be 1 MB or smaller.');
        }
        if ($uploadError !== UPLOAD_ERR_OK) {
            throw new HttpException(422, 'Unable to upload the selected image.');
        }
        if (($file['size'] ?? 0) < 1 || $file['size'] > 1024 * 1024 || !is_uploaded_file($file['tmp_name'])) {
            throw new HttpException(422, 'Profile images must be 1 MB or smaller.');
        }
        $imageInfo = @getimagesize($file['tmp_name']);
        $types = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
        $imageType = is_array($imageInfo) ? ($imageInfo[2] ?? null) : null;
        if (!isset($types[$imageType])) {
            throw new HttpException(422, 'Upload a JPEG, PNG, or WebP image.');
        }
        if (($imageInfo[0] ?? 0) > 4096 || ($imageInfo[1] ?? 0) > 4096) {
            throw new HttpException(422, 'Profile image dimensions must not exceed 4096 pixels.');
        }

        $directory = dirname(__DIR__) . '/public/uploads/avatars';
        if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
            throw new RuntimeException('Unable to create the profile-image directory.');
        }
        $old = $this->profileUser($session['id']);
        $filename = $session['id'] . '-' . bin2hex(random_bytes(16)) . '.' . $types[$imageType];
        $destination = $directory . '/' . $filename;
        if (!move_uploaded_file($file['tmp_name'], $destination)) {
            throw new RuntimeException('Unable to store the profile image.');
        }
        $storedPath = '/uploads/avatars/' . $filename;
        $this->db->prepare('UPDATE users SET avatar_url = ? WHERE id = ?')->execute([$storedPath, $session['id']]);
        $oldUrl = $old['avatar_url'] ?? null;
        $oldPath = $this->managedAvatarPath($oldUrl);
        if ($oldPath !== null) {
            $oldFile = $directory . '/' . basename($oldPath);
            if (is_file($oldFile)) {
                unlink($oldFile);
            }
        }
        $this->audit($session['id'], 'profile.avatar_uploaded');
        return ['user' => $this->profileUser($session['id'])];
    }

    private function profileUser(string $userId): array
    {
        $user = $this->db->prepare('SELECT id, email, full_name, avatar_url, plan, email_verified_at FROM users WHERE id = ? LIMIT 1');
        $user->execute([$userId]);
        $profile = $user->fetch() ?: throw new RuntimeException('User profile was not found.');
        $profile['avatar_url'] = $this->resolvedAvatarUrl($profile['avatar_url'] ?? null);
        return $profile;
    }

    private function managedAvatarPath(mixed $avatarUrl): ?string
    {
        if (!is_string($avatarUrl) || $avatarUrl === '') {
            return null;
        }
        $path = parse_url($avatarUrl, PHP_URL_PATH);
        if (!is_string($path) || !preg_match('#^/uploads/avatars/[a-zA-Z0-9-]+\.(?:jpe?g|png|webp)$#', $path)) {
            return null;
        }
        return $path;
    }

    private function resolvedAvatarUrl(mixed $avatarUrl): ?string
    {
        if (!is_string($avatarUrl) || $avatarUrl === '') {
            return null;
        }
        $path = $this->managedAvatarPath($avatarUrl);
        if ($path !== null) {
            $file = dirname(__DIR__) . '/public' . $path;
            if (!is_file($file)) {
                return null;
            }
        }
        return $path === null
            ? $avatarUrl
            : rtrim((string) env('APP_URL', ''), '/') . $path;
    }

    private function assertLoginNotRateLimited(string $email): void
    {
        $stmt = $this->db->prepare('SELECT COUNT(*) FROM login_attempts WHERE success = 0 AND created_at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE) AND (email = ? OR ip_address = ?)');
        $stmt->execute([$email, clientIp()]);
        if ((int) $stmt->fetchColumn() >= 10) {
            throw new HttpException(429, 'Too many sign-in attempts. Try again later.');
        }
    }

    private function logLoginAttempt(string $email, ?string $userId, bool $success, ?string $reason): void
    {
        $this->db->prepare('INSERT INTO login_attempts (email, user_id, ip_address, user_agent, success, failure_reason) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([$email, $userId, clientIp(), userAgent(), $success ? 1 : 0, $reason]);
    }

    private function audit(?string $userId, string $action, array $metadata = []): void
    {
        $this->db->prepare('INSERT INTO audit_log (user_id, action, ip_address, user_agent, metadata) VALUES (?, ?, ?, ?, ?)')
            ->execute([$userId, $action, clientIp(), userAgent(), $metadata ? json_encode($metadata) : null]);
    }

    public function confirmEmailGet(array $input): string
    {
        $success = false;
        $message = '';
        $origins = explode(',', (string) env('APP_ALLOWED_ORIGINS', ''));
        $webUrl = !empty($origins[0]) ? trim($origins[0]) : 'http://localhost:8080';
        
        try {
            $dataBase64 = $input['data'] ?? null;
            $signature = $input['signature'] ?? null;
            
            if ($dataBase64 !== null && $signature !== null) {
                // 1. Google Signed Link flow
                $tokenDataStr = base64_decode($dataBase64);
                $expectedSignature = hash_hmac('sha256', $tokenDataStr, env('GOOGLE_OAUTH_CLIENT_SECRET', 'url_defender_secret'));
                if (!hash_equals($expectedSignature, $signature)) {
                    throw new Exception('Invalid signature or verification link.');
                }
                
                $tokenData = json_decode($tokenDataStr, true);
                if (time() > ($tokenData['expires'] ?? 0)) {
                    throw new Exception('Verification link has expired.');
                }
                
                $email = strtolower(trim((string)($tokenData['email'] ?? '')));
                $name = trim((string)($tokenData['name'] ?? ''));
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                    throw new Exception('Invalid email parameter.');
                }
                
                $this->db->beginTransaction();
                $existingStatement = $this->db->prepare('SELECT id, email_verified_at FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1 FOR UPDATE');
                $existingStatement->execute([$email]);
                $user = $existingStatement->fetch();
                if ($user && $user['email_verified_at'] !== null) {
                    $this->db->commit();
                    $success = true;
                    $message = 'Your email address is already verified. You can now close this tab and sign in!';
                } else if ($user) {
                    $this->db->prepare('UPDATE users SET email_verified_at = UTC_TIMESTAMP(), is_active = 1 WHERE id = ?')->execute([$user['id']]);
                    $this->audit($user['id'], 'auth.email_verified');
                    $this->db->commit();
                    $success = true;
                    $message = 'Your account has been successfully verified! You can now close this tab and sign in using Google.';
                } else {
                    $userId = uuid();
                    $this->db->prepare('INSERT INTO users (id, email, password_hash, full_name, email_verified_at, is_active, last_login_at) VALUES (?, ?, ?, ?, UTC_TIMESTAMP(), 1, UTC_TIMESTAMP())')
                        ->execute([
                            $userId,
                            $email,
                            password_hash(bin2hex(random_bytes(32)), PASSWORD_ARGON2ID),
                            $name === '' ? explode('@', $email)[0] : $name,
                        ]);
                    $this->db->prepare("INSERT INTO user_roles (id, user_id, role) VALUES (?, ?, 'user')")
                        ->execute([uuid(), $userId]);
                    $this->audit($userId, 'auth.google_registered', ['provider' => 'google']);
                    $this->db->commit();
                    $success = true;
                    $message = 'Your Google account has been successfully verified! You can now close this tab and sign in using Google.';
                }
            } else {
                // 2. Standard OTP Verification Link flow (email + code)
                $email = strtolower(trim((string) ($input['email'] ?? '')));
                $code = trim((string) ($input['code'] ?? ''));
                if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !preg_match('/^\d{6}$/', $code)) {
                    throw new Exception('Invalid email or verification code.');
                }
                
                $this->db->beginTransaction();
                $userStatement = $this->db->prepare('SELECT id, email_verified_at FROM users WHERE email = ? AND deleted_at IS NULL LIMIT 1 FOR UPDATE');
                $userStatement->execute([$email]);
                $user = $userStatement->fetch();
                if ($user && $user['email_verified_at'] !== null) {
                    $this->db->commit();
                    $success = true;
                    $message = 'Your email address is already verified. You can now log into the app!';
                } else if (!$user) {
                    $this->db->commit();
                    throw new Exception('Account not found.');
                } else {
                    $stmt = $this->db->prepare('SELECT ev.*, (ev.expires_at <= UTC_TIMESTAMP()) AS is_expired FROM email_verifications ev WHERE ev.user_id = ? AND ev.consumed_at IS NULL ORDER BY ev.created_at DESC LIMIT 1 FOR UPDATE');
                    $stmt->execute([$user['id']]);
                    $verification = $stmt->fetch();
                    if (!$verification || (bool) $verification['is_expired'] || (int) $verification['attempts'] >= 5) {
                        $this->db->commit();
                        throw new Exception('Verification link is invalid or expired.');
                    }
                    
                    if (!password_verify($code, $verification['code_hash'])) {
                        $this->db->prepare('UPDATE email_verifications SET attempts = attempts + 1 WHERE id = ?')->execute([$verification['id']]);
                        $this->db->commit();
                        throw new Exception('Verification link is invalid.');
                    }
                    
                    $this->db->prepare('UPDATE email_verifications SET consumed_at = UTC_TIMESTAMP(), verified_ip = ?, verified_user_agent = ? WHERE id = ?')
                        ->execute([clientIp(), userAgent(), $verification['id']]);
                    $this->db->prepare('UPDATE users SET email_verified_at = UTC_TIMESTAMP(), is_active = 1 WHERE id = ?')->execute([$user['id']]);
                    $this->audit($user['id'], 'auth.email_verified');
                    $this->db->commit();
                    $success = true;
                    $message = 'Your email address has been successfully verified! You can now log into the URL Defender application.';
                }
            }
        } catch (Throwable $e) {
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }
            $success = false;
            $message = $e->getMessage();
        }
        
        $title = $success ? 'Verification Successful' : 'Verification Failed';
        $color = $success ? '#22C55E' : '#EF4444';
        $icon = $success ? '✅' : '❌';
        
        return '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>' . $title . '</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: #F8FAFC; color: #0F172A; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 20px; }
    .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); text-align: center; max-width: 420px; border: 1px solid #E2E8F0; }
    .icon { font-size: 54px; margin-bottom: 20px; }
    h1 { font-size: 24px; margin: 0 0 16px 0; color: ' . $color . '; }
    p { font-size: 15px; color: #475569; line-height: 1.6; margin: 0 0 30px 0; }
    .btn { display: inline-block; background-color: #16A34A; color: white; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; box-shadow: 0 2px 4px rgba(22,163,74,0.2); }
    .btn:hover { background-color: #15803d; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">' . $icon . '</div>
    <h1>' . $title . '</h1>
    <p>' . htmlspecialchars($message) . '</p>
    <a href="' . htmlspecialchars($webUrl, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . '" class="btn">Go to URL Defender</a>
  </div>
</body>
</html>';
    }

    public function getSessions(array $session): array
    {
        $stmt = $this->db->prepare('SELECT id, ip_address, user_agent, created_at FROM auth_sessions WHERE user_id = ? AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP() ORDER BY created_at DESC');
        $stmt->execute([$session['id']]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $sessions = [];
        foreach ($rows as $row) {
            $isCurrent = ($row['id'] === $session['session_id']);
            
            // Basic User Agent parser
            $ua = $row['user_agent'] ?: '';
            $browser = 'Browser';
            $device = 'Device';

            if (stripos($ua, 'firefox') !== false) {
                $browser = 'Firefox';
            } elseif (stripos($ua, 'chrome') !== false) {
                $browser = 'Chrome';
            } elseif (stripos($ua, 'safari') !== false) {
                $browser = 'Safari';
            } elseif (stripos($ua, 'edge') !== false) {
                $browser = 'Edge';
            } elseif (stripos($ua, 'opera') !== false) {
                $browser = 'Opera';
            }

            if (stripos($ua, 'iphone') !== false) {
                $device = 'iPhone';
            } elseif (stripos($ua, 'ipad') !== false) {
                $device = 'iPad';
            } elseif (stripos($ua, 'android') !== false) {
                $device = 'Android Device';
            } elseif (stripos($ua, 'windows') !== false) {
                $device = 'Windows PC';
            } elseif (stripos($ua, 'macintosh') !== false || stripos($ua, 'mac os') !== false) {
                $device = 'MacBook';
            } elseif (stripos($ua, 'linux') !== false) {
                $device = 'Linux PC';
            }

            $sessions[] = [
                'id' => $row['id'],
                'device' => $device,
                'browser' => $browser . ' · ' . ($row['ip_address'] ?: 'Unknown IP'),
                'isCurrent' => $isCurrent ? 'true' : 'false',
            ];
        }

        return ['sessions' => $sessions];
    }

    public function revokeSession(array $session, string $sessionId): array
    {
        if ($sessionId === $session['session_id']) {
            throw new HttpException(400, 'Cannot revoke your current session.');
        }

        $stmt = $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE id = ? AND user_id = ? AND revoked_at IS NULL');
        $stmt->execute([$sessionId, $session['id']]);

        return ['success' => true, 'message' => 'Session revoked.'];
    }

    public function revokeAllOtherSessions(array $session): array
    {
        $stmt = $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND id != ? AND revoked_at IS NULL');
        $stmt->execute([$session['id'], $session['session_id']]);

        return ['success' => true, 'message' => 'All other sessions revoked.'];
    }

    public function deleteAccount(array $session): array
    {
        $stmt = $this->db->prepare('UPDATE users SET deleted_at = UTC_TIMESTAMP(), is_active = 0 WHERE id = ?');
        $stmt->execute([$session['id']]);

        $stmt2 = $this->db->prepare('UPDATE auth_sessions SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ?');
        $stmt2->execute([$session['id']]);

        return ['success' => true, 'message' => 'Account deleted.'];
    }

    public function removeAvatar(array $session): array
    {
        $stmt = $this->db->prepare('UPDATE users SET avatar_url = NULL WHERE id = ?');
        $stmt->execute([$session['id']]);

        $stmt2 = $this->db->prepare('SELECT * FROM users WHERE id = ? LIMIT 1');
        $stmt2->execute([$session['id']]);
        $updatedUser = $stmt2->fetch(PDO::FETCH_ASSOC);

        return ['success' => true, 'user' => $this->publicUser($updatedUser)];
    }

    private function publicUser(array $user): array
    {
        return [
            'id' => $user['id'], 'email' => $user['email'], 'full_name' => $user['full_name'],
            'avatar_url' => $this->resolvedAvatarUrl($user['avatar_url'] ?? null), 'plan' => $user['plan'], 'email_verified_at' => $user['email_verified_at'],
        ];
    }
}
