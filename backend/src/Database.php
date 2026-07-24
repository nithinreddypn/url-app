<?php
declare(strict_types=1);

// Backward-compatible loader for existing URL Defender entry points.
// The isolated configuration is intentionally outside public_html/config,
// which is shared with another application and must remain unchanged.
require_once dirname(__DIR__) . '/config/database.php';
