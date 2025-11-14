<?php

declare(strict_types=1);

/**
 * OpenEMR preload helper for FrankenPHP.
 *
 * Even when FrankenPHP is running in classic per-request mode we can warm up the
 * opcode cache and PHP autoloader to reduce the first-hit latency.  When/if worker
 * mode is introduced later this file can be extended with
 * frankenphp_handle_request() without touching the Docker image again.
 */

if (!function_exists('opcache_compile_file')) {
    return;
}

if (!isset($_SERVER['DOCUMENT_ROOT'])) {
    $_SERVER['DOCUMENT_ROOT'] = __DIR__;
}
if (!isset($_SERVER['HTTP_HOST'])) {
    $_SERVER['HTTP_HOST'] = 'localhost';
}
if (!isset($_SERVER['REQUEST_URI'])) {
    $_SERVER['REQUEST_URI'] = '/';
}

$autoload = __DIR__ . '/vendor/autoload.php';
if (!is_file($autoload)) {
    return;
}

require_once $autoload;

$preloadCandidates = array_unique([
    __DIR__ . '/interface/globals.php',
    __DIR__ . '/library/sql.inc',
    __DIR__ . '/library/api.inc',
    __DIR__ . '/src/Common/Session/SessionUtil.php',
    __DIR__ . '/src/Common/Session/SessionHandler.php',
    __DIR__ . '/interface/login/login.php',
    __DIR__ . '/interface/main/main_screen.php',
    __DIR__ . '/src/Common/Http/HttpRestRouteHandler.php',
    __DIR__ . '/src/Common/Auth/SessionGuard.php',
]);

foreach ($preloadCandidates as $file) {
    if (is_file($file)) {
        @opcache_compile_file($file);
    }
}

// Worker mode intentionally disabled; leave early so normal request lifecycle proceeds.
