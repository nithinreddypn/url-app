<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('POST', 'PATCH');
$context = authenticatedContext();
$input = jsonInput();
$updates = [];
$parameters = ['id' => $context['user']['id']];

if (array_key_exists('full_name', $input)) {
    $updates[] = 'full_name = :full_name';
    $parameters['full_name'] = requiredString($input, 'full_name', 120);
}

if (array_key_exists('avatar_base64', $input)) {
    $encoded = requiredString($input, 'avatar_base64', 8000000);
    if (str_contains($encoded, ',')) {
        $encoded = explode(',', $encoded, 2)[1];
    }
    $bytes = base64_decode($encoded, true);
    $maxBytes = min(max((int) envValue('MAX_AVATAR_BYTES', '5242880'), 1024), 10485760);
    if ($bytes === false || strlen($bytes) > $maxBytes) {
        throw new ApiError(422, 'Profile image is invalid or too large.');
    }
    $imageInfo = @getimagesizefromstring($bytes);
    $types = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
    $imageType = is_array($imageInfo) ? ($imageInfo[2] ?? null) : null;
    if (!is_int($imageType) || !isset($types[$imageType])) {
        throw new ApiError(422, 'Profile image must be JPEG, PNG, or WebP.');
    }
    $baseUrl = rtrim(envValue('APP_PUBLIC_URL'), '/');
    if ($baseUrl === '') {
        throw new RuntimeException('APP_PUBLIC_URL is not configured.');
    }
    $fileName = bin2hex(random_bytes(24)) . '.' . $types[$imageType];
    $uploadDirectory = dirname(__DIR__) . '/uploads';
    if (!is_dir($uploadDirectory) && !mkdir($uploadDirectory, 0755, true) && !is_dir($uploadDirectory)) {
        throw new RuntimeException('The upload directory is unavailable.');
    }
    if (file_put_contents($uploadDirectory . '/' . $fileName, $bytes, LOCK_EX) === false) {
        throw new RuntimeException('The profile image could not be stored.');
    }
    $updates[] = 'avatar_url = :avatar_url';
    $parameters['avatar_url'] = $baseUrl . '/uploads/' . rawurlencode($fileName);
}

if ($updates === []) {
    throw new ApiError(422, 'Provide full_name or avatar_base64 to update.');
}

$statement = database()->prepare('UPDATE users SET ' . implode(', ', $updates) . ' WHERE id = :id');
$statement->execute($parameters);
$profile = database()->prepare(
    'SELECT id, email, full_name, avatar_url, plan, email_verified_at, created_at, updated_at '
    . 'FROM users WHERE id = :id LIMIT 1'
);
$profile->execute(['id' => $context['user']['id']]);

respondJson(200, true, 'Profile updated successfully.', ['user' => publicUser($profile->fetch())]);
