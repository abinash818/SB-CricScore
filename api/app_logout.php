<?php
// api/app_logout.php
// Flutter app logout — revokes the Bearer token
// POST {} (with Authorization: Bearer <token> header)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$token = app_get_token();
if ($token) {
    $pdo->prepare("DELETE FROM api_tokens WHERE token=?")->execute([$token]);
}

echo json_encode(['success' => true, 'message' => 'Logged out successfully.']);
