<?php
declare(strict_types=1);

require dirname(__DIR__) . '/src/Support.php';
loadEnv(dirname(__DIR__) . '/.env');
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/HttpClient.php';
require dirname(__DIR__) . '/src/GoogleIdTokenVerifier.php';
require dirname(__DIR__) . '/src/Mailer.php';
require dirname(__DIR__) . '/src/AuthController.php';
require dirname(__DIR__) . '/src/ScanController.php';
require dirname(__DIR__) . '/src/PaymentController.php';
require dirname(__DIR__) . '/src/AdminController.php';
require dirname(__DIR__) . '/src/CommunityReportsController.php';
require dirname(__DIR__) . '/src/NotificationController.php';

header('Vary: Origin');
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '' && allowedOrigin($origin)) {
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept, X-Requested-With');
    header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');
    header('Access-Control-Max-Age: 86400');
} elseif ($origin !== '') {
    logRejectedOrigin($origin, $_SERVER['REQUEST_URI'] ?? '/');
}
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';

// Dynamically strip the subdirectory containing index.php (e.g. /backend/public)
$scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
$scriptDir = rtrim($scriptDir, '/');
if ($scriptDir !== '') {
    $path = preg_replace('#^' . preg_quote($scriptDir, '#') . '#', '', $path) ?: '/';
}

$path = preg_replace('#^/api/v1#', '', $path) ?: '/';
$path = preg_replace('#^/index\.php#', '', $path) ?: '/';

// Serve managed avatar files through the front controller so browser clients
// receive the same validated CORS headers as JSON API responses.
if ($method === 'GET' && preg_match('#^/uploads/avatars/([a-zA-Z0-9-]+\.(?:jpe?g|png|webp))$#i', $path, $avatarMatch)) {
    $avatarFile = __DIR__ . '/uploads/avatars/' . $avatarMatch[1];
    if (!is_file($avatarFile)) {
        respond(404, ['success' => false, 'message' => 'Profile image not found.']);
    }
    $imageInfo = @getimagesize($avatarFile);
    $mime = is_array($imageInfo) ? ($imageInfo['mime'] ?? null) : null;
    if (!is_string($mime) || !in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true)) {
        respond(404, ['success' => false, 'message' => 'Profile image not found.']);
    }
    if ($origin !== '' && allowedOrigin($origin)) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Access-Control-Allow-Credentials: true');
    }
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . (string) filesize($avatarFile));
    header('Cache-Control: public, max-age=86400');
    header('X-Content-Type-Options: nosniff');
    readfile($avatarFile);
    exit;
}

try {
    $db = Database::connection();
    $auth = new AuthController($db, new Mailer());
    $scans = new ScanController($db);
    $notifications = new NotificationController($db);
    $payments = new PaymentController($db);
    $admin = new AdminController($db);
    $community = new CommunityReportsController($db);
    if ($method === 'GET' && $path === '/health') {
        respond(200, ['status' => 'ok']);
    }
    if ($method === 'GET' && $path === '/auth/confirm-email') {
        header('Content-Type: text/html; charset=utf-8');
        echo $auth->confirmEmailGet($_GET);
        exit;
    }
    if ($method === 'POST' && $path === '/auth/register') {
        respond(201, $auth->register(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/verify-email') {
        respond(200, $auth->verifyEmail(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/resend-verification') {
        respond(202, $auth->resendVerification(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/login') {
        respond(200, $auth->login(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/google') {
        respond(200, $auth->googleLogin(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/forgot-password') {
        respond(202, $auth->forgotPassword(jsonBody()));
    }
    if ($method === 'POST' && $path === '/auth/reset-password') {
        respond(200, $auth->resetPassword(jsonBody()));
    }
    if ($method === 'POST' && $path === '/payments/webhook') {
        respond(200, $payments->webhook(rawBody(), $_SERVER['HTTP_X_RAZORPAY_SIGNATURE'] ?? ''));
    }

    $user = $auth->currentUser();
    if ($method === 'POST' && $path === '/auth/logout') {
        respond(200, $auth->logout($user));
    }
    if ($method === 'POST' && $path === '/auth/change-password') {
        respond(200, $auth->changePassword($user, jsonBody()));
    }
    if ($method === 'GET' && $path === '/me') {
        unset($user['session_id']);
        respond(200, ['user' => $user]);
    }
    if ($method === 'PATCH' && $path === '/me') {
        respond(200, $auth->updateProfile($user, jsonBody()));
    }
    if ($method === 'DELETE' && $path === '/me') {
        respond(200, $auth->deleteAccount($user));
    }
    if ($method === 'POST' && $path === '/me/avatar') {
        respond(200, $auth->uploadAvatar($user));
    }
    if ($method === 'DELETE' && $path === '/me/avatar') {
        respond(200, $auth->removeAvatar($user));
    }
    if ($method === 'GET' && $path === '/me/sessions') {
        respond(200, $auth->getSessions($user));
    }
    if ($method === 'DELETE' && $path === '/me/sessions') {
        respond(200, $auth->revokeAllOtherSessions($user));
    }
    if ($method === 'DELETE' && preg_match('#^/me/sessions/([a-zA-Z0-9-]+)$#i', $path, $matches)) {
        respond(200, $auth->revokeSession($user, $matches[1]));
    }
    if ($method === 'GET' && $path === '/scans') {
        respond(200, $scans->list($user));
    }
    if ($method === 'POST' && $path === '/url/lookup') {
        respond(200, $scans->lookup($user, jsonBody()));
    }
    if ($method === 'POST' && $path === '/scans') {
        $createdScan = $scans->create($user, jsonBody());
        respond(($createdScan['cached'] ?? false) ? 200 : 202, $createdScan);
    }
    if ($method === 'GET' && preg_match('#^/scans/([0-9a-f-]{36})$#i', $path, $matches)) {
        respond(200, ['scan' => $scans->detail($user, $matches[1])]);
    }
    if ($method === 'DELETE' && preg_match('#^/scans/([0-9a-f-]{36})$#i', $path, $matches)) {
        respond(200, $scans->delete($user, $matches[1]));
    }
    if ($method === 'GET' && $path === '/usage') {
        respond(200, $scans->usage($user));
    }
    if ($method === 'GET' && $path === '/notifications') {
        respond(200, $notifications->list($user));
    }
    if ($method === 'PATCH' && preg_match('#^/notifications/([0-9a-f-]{36})/read$#i', $path, $matches)) {
        respond(200, $notifications->markRead($user, $matches[1]));
    }
    if ($method === 'POST' && $path === '/notifications/read-all') {
        respond(200, $notifications->markAllRead($user));
    }
    if ($method === 'DELETE' && $path === '/notifications') {
        respond(200, $notifications->clearAll($user));
    }
    if ($method === 'GET' && $path === '/plans') {
        respond(200, $payments->plans());
    }
    if ($method === 'POST' && $path === '/payments/orders') {
        respond(201, $payments->createOrder($user, jsonBody()));
    }
    if ($method === 'POST' && $path === '/payments/verify') {
        respond(200, $payments->verifyOrder($user, jsonBody()));
    }
    if ($method === 'POST' && $path === '/payments/coupons/validate') {
        respond(200, $payments->validateCoupon($user, jsonBody()));
    }
    if ($method === 'POST' && $path === '/payments/cancel') {
        respond(200, $payments->cancelSubscription($user));
    }
    if ($method === 'GET' && $path === '/payments') {
        respond(200, $payments->listPayments($user));
    }
    if ($method === 'GET' && $path === '/admin/users') {
        respond(200, $admin->users($user));
    }
    if ($method === 'PATCH' && preg_match('#^/admin/users/([0-9a-f-]{36})/status$#i', $path, $matches)) {
        respond(200, $admin->setUserActive($user, $matches[1], jsonBody()));
    }
    if ($method === 'GET' && $path === '/admin/audit-log') {
        respond(200, $admin->auditLog($user));
    }
    // ─── Community Threat Reports API ───
    if ($method === 'POST' && $path === '/community-reports') {
        respond(201, $community->submitReport($user, jsonBody()));
    }
    if ($method === 'POST' && $path === '/community-reports/vote') {
        respond(200, $community->submitVote($user, jsonBody()));
    }
    if ($method === 'GET' && $path === '/community-reports/verified') {
        respond(200, $community->getVerified($user));
    }
    if ($method === 'GET' && $path === '/community-reports/status') {
        respond(200, $community->checkStatus($user));
    }
    if ($method === 'GET' && $path === '/community-reports/categories') {
        respond(200, $community->getCategories($user));
    }
    if ($method === 'GET' && $path === '/community-reports/trending') {
        respond(200, $community->getTrending($user));
    }
    if ($method === 'GET' && $path === '/community-reports/top') {
        respond(200, $community->getTopReports($user));
    }
    if ($method === 'GET' && preg_match('#^/community-reports/domain/([^/]+)$#i', $path, $matches)) {
        respond(200, $community->getDomainDetails($user, urldecode($matches[1])));
    }
    if ($method === 'GET' && $path === '/community-reports/my-reputation') {
        respond(200, $community->getMyReputation($user));
    }
    if ($method === 'GET' && $path === '/community-reports/my-reports') {
        respond(200, $community->getMyReports($user));
    }
    if ($method === 'GET' && $path === '/community-reports/feed') {
        respond(200, $community->getLatestReports($user));
    }
    if ($method === 'GET' && $path === '/community-reports/verified') {
        respond(200, $community->getVerified($user));
    }
    if ($method === 'GET' && $path === '/community-reports/alerts') {
        respond(200, $community->getAlerts($user));
    }
    if ($method === 'GET' && $path === '/community-reports/latest') {
        respond(200, $community->getLatestReports($user));
    }
    if ($method === 'GET' && $path === '/community-reports/pending') {
        respond(200, $community->getPendingReports($user));
    }
    if ($method === 'GET' && $path === '/community-reports/most-reported') {
        respond(200, $community->getMostReported($user));
    }
    if ($method === 'GET' && $path === '/community-reports/recently-verified') {
        respond(200, $community->getRecentlyVerified($user));
    }
    if ($method === 'GET' && $path === '/community-reports/stats') {
        respond(200, $community->getCommunityStats($user));
    }
    if ($method === 'GET' && preg_match('#^/community-reports/([0-9a-f-]{36})/detail$#i', $path, $matches)) {
        respond(200, $community->getReportDetail($user, $matches[1]));
    }
    if ($method === 'GET' && $path === '/admin/community-reports') {
        respond(200, $community->getAdminReports($user));
    }
    if ($method === 'POST' && preg_match('#^/admin/community-reports/([0-9a-f-]{36})/approve$#i', $path, $matches)) {
        respond(200, $community->approveReport($user, $matches[1]));
    }
    if ($method === 'POST' && preg_match('#^/admin/community-reports/([0-9a-f-]{36})/reject$#i', $path, $matches)) {
        respond(200, $community->rejectReport($user, $matches[1]));
    }
    if ($method === 'POST' && preg_match('#^/admin/community-reports/([0-9a-f-]{36})/merge$#i', $path, $matches)) {
        $body = json_decode(file_get_contents('php://input'), true) ?? [];
        $targetId = trim((string) ($body['target_id'] ?? ''));
        respond(200, $community->mergeReport($user, $matches[1], $targetId));
    }
    if ($method === 'POST' && preg_match('#^/admin/reporters/([0-9a-f-]{36})/block$#i', $path, $matches)) {
        respond(200, $community->blockReporter($user, $matches[1]));
    }

    throw new HttpException(404, 'Endpoint not found.');
} catch (HttpException $error) {
    respond($error->status, ['success' => false, 'message' => $error->getMessage()]);
} catch (DatabaseConnectionException $error) {
    respond(500, ['success' => false, 'message' => 'Unable to connect to the database.']);
} catch (PDOException $error) {
    if (filter_var(env('APP_DEBUG', 'false'), FILTER_VALIDATE_BOOL)) {
        error_log($error->getMessage());
    }
    respond(500, ['success' => false, 'message' => 'Unable to process your request.']);
} catch (Throwable $error) {
    if (filter_var(env('APP_DEBUG', 'false'), FILTER_VALIDATE_BOOL)) {
        error_log($error->getMessage());
    }
    respond(500, ['success' => false, 'message' => 'Unable to process your request.']);
}
