<?php
// api/profile_get.php
// GET /api/profile_get.php (Requires Authorization: Bearer <token>)
// Fetches the authenticated user's profile

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$user = app_require_auth($pdo);

echo json_encode([
    'success' => true,
    'user'    => [
        'id'               => (int)$user['id'],
        'mobile'           => $user['mobile'],
        'name'             => $user['name'] ?? null,
        'dob'              => $user['dob'] ?? null,
        'city'             => $user['city'] ?? null,
        'profile_pic'      => $user['profile_pic'] ?? null,
        'batting_style'    => $user['batting_style'] ?? null,
        'bowling_style'    => $user['bowling_style'] ?? null,
        'role'             => $user['role'] ?? null,
        'jersey_number'    => $user['jersey_number'] ?? null,
        'preferred_format' => $user['preferred_format'] ?? null,
        'language'         => $user['language'] ?? 'en',
        'profile_complete' => (int)($user['profile_complete'] ?? 0),
        'created_at'       => $user['created_at'] ?? null,
    ]
]);
