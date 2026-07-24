<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/bootstrap.php';
require_once dirname(__DIR__) . '/middleware/auth.php';

requireMethod('GET');
$context = authenticatedContext();
respondJson(200, true, 'Profile fetched successfully.', ['user' => publicUser($context['user'])]);

