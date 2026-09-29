<?php
// api/notifications_ops.php
// Push Notifications & Live Match Alerts API
// GET  /api/notifications_ops.php?action=list
// POST /api/notifications_ops.php?action=save_token
// POST /api/notifications_ops.php?action=read

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Auto-create notifications & fcm_tokens tables if missing
try {
    $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    if ($driver === 'sqlite') {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                type TEXT DEFAULT 'system',
                target_id INTEGER DEFAULT 0,
                is_read INTEGER DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE TABLE IF NOT EXISTS fcm_tokens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                token TEXT NOT NULL,
                updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                UNIQUE(user_id)
            );
        ");
    } else {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS notifications (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT,
                title VARCHAR(255) NOT NULL,
                body TEXT NOT NULL,
                type VARCHAR(50) DEFAULT 'system',
                target_id INT DEFAULT 0,
                is_read TINYINT(1) DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS fcm_tokens (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                token VARCHAR(255) NOT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_user (user_id)
            );
        ");
    }
} catch (Throwable $e) {}

$user = app_optional_auth($pdo);
$userId = (int)($user['id'] ?? 0);
$action = $_GET['action'] ?? ($_POST['action'] ?? 'list');

// ── 1. LIST NOTIFICATIONS ──────────────────────────────────────────────────
if ($action === 'list') {
    $stmt = $pdo->prepare("
        SELECT * FROM notifications 
        WHERE user_id = ? OR user_id IS NULL OR user_id = 0 
        ORDER BY id DESC LIMIT 30
    ");
    $stmt->execute([$userId]);
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $unreadStmt = $pdo->prepare("
        SELECT COUNT(*) as unread FROM notifications 
        WHERE (user_id = ? OR user_id IS NULL OR user_id = 0) AND is_read = 0
    ");
    $unreadStmt->execute([$userId]);
    $unreadCount = (int)($unreadStmt->fetch(PDO::FETCH_ASSOC)['unread'] ?? 0);

    echo json_encode([
        'success'      => true,
        'unread_count' => $unreadCount,
        'notifications'=> $items
    ]);
    exit;
}

// ── 2. SAVE FCM / PUSH TOKEN ───────────────────────────────────────────────
if ($action === 'save_token') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $token = trim($input['token'] ?? '');

    if ($userId <= 0 || empty($token)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'User auth and token required']);
        exit;
    }

    $now = date('Y-m-d H:i:s');
    $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    if ($driver === 'sqlite') {
        $st = $pdo->prepare("INSERT OR REPLACE INTO fcm_tokens (user_id, token, updated_at) VALUES (?, ?, ?)");
    } else {
        $st = $pdo->prepare("INSERT INTO fcm_tokens (user_id, token, updated_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE token = VALUES(token), updated_at = VALUES(updated_at)");
    }
    $st->execute([$userId, $token, $now]);

    echo json_encode(['success' => true, 'message' => 'Push token saved successfully']);
    exit;
}

// ── 3. MARK NOTIFICATION AS READ ──────────────────────────────────────────
if ($action === 'read') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $notifId = (int)($input['notification_id'] ?? 0);

    if ($notifId > 0) {
        $st = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE id = ?");
        $st->execute([$notifId]);
    } else {
        // Mark all as read
        $st = $pdo->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? OR user_id IS NULL OR user_id = 0");
        $st->execute([$userId]);
    }

    echo json_encode(['success' => true, 'message' => 'Notification marked as read']);
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);
