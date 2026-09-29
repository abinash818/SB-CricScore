<?php
// api/fcm_token_register.php
// Register / Update FCM Device Token
// POST /api/fcm_token_register.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Auto create table
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS fcm_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INT DEFAULT NULL,
        fcm_token TEXT NOT NULL UNIQUE,
        device_type VARCHAR(50) DEFAULT 'android',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
} catch (Throwable $e) {}

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$fcmToken = trim($input['fcm_token'] ?? '');
$deviceType = trim($input['device_type'] ?? 'android');
$userId = null;

$user = getAuthUser();
if ($user && isset($user['id'])) {
    $userId = (int)$user['id'];
}

if (empty($fcmToken)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'fcm_token is required']);
    exit;
}

try {
    // Upsert FCM token
    $stmt = $pdo->prepare("
        INSERT INTO fcm_tokens (user_id, fcm_token, device_type, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(fcm_token) DO UPDATE SET
            user_id = EXCLUDED.user_id,
            device_type = EXCLUDED.device_type,
            updated_at = CURRENT_TIMESTAMP
    ");
    $stmt->execute([$userId, $fcmToken, $deviceType]);

    echo json_encode(['success' => true, 'message' => 'FCM Token registered successfully']);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
