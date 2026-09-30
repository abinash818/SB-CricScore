<?php
// api/otp_verify.php
// Verifies OTP and logs in / registers the user
// POST { "mobile": "9876543210", "otp": "123456" }
// Returns: { success, token, user, is_new_user }

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../db.php';

$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$mobile = trim($body['mobile'] ?? '');
$otp    = trim($body['otp']    ?? '');

// Basic validation
if (!preg_match('/^[6-9]\d{9}$/', $mobile)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid mobile number.']);
    exit;
}
if (!preg_match('/^\d{6}$/', $otp)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'OTP must be 6 digits.']);
    exit;
}

$driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

// ── Fetch latest unverified, unexpired OTP for this mobile ───────────────────
$now = date('Y-m-d H:i:s');
$otpStmt = $pdo->prepare("
    SELECT id, otp, attempts, expires_at
    FROM mobile_otps
    WHERE mobile = ? AND verified = 0
      AND expires_at >= ?
    ORDER BY id DESC
    LIMIT 1
");
$otpStmt->execute([$mobile, $now]);
$otpRow = $otpStmt->fetch();

if (!$otpRow) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'OTP expired or not found. Please request a new OTP.']);
    exit;
}

// ── Max attempts guard (3 tries max) ─────────────────────────────────────────────
if ((int)$otpRow['attempts'] >= 3) {
    // Invalidate this OTP
    $pdo->prepare("UPDATE mobile_otps SET verified=2 WHERE id=?")->execute([$otpRow['id']]);
    http_response_code(429);
    echo json_encode(['success' => false, 'message' => 'Too many wrong attempts (Max 3). Please request a new OTP.']);
    exit;
}

// ── Increment attempt counter ─────────────────────────────────────────────────
$pdo->prepare("UPDATE mobile_otps SET attempts = attempts + 1 WHERE id=?")->execute([$otpRow['id']]);

// ── Verify OTP ────────────────────────────────────────────────────────────────
if ($otpRow['otp'] !== $otp) {
    $remaining = 3 - ((int)$otpRow['attempts'] + 1);
    http_response_code(401);
    echo json_encode([
        'success'   => false,
        'message'   => "Wrong OTP. {$remaining} attempt(s) remaining.",
        'remaining' => $remaining
    ]);
    exit;
}

// ── Mark OTP as verified ──────────────────────────────────────────────────────
$pdo->prepare("UPDATE mobile_otps SET verified=1 WHERE id=?")->execute([$otpRow['id']]);

// ── Ensure app_users & api_tokens tables exist (MySQL) ──
$pdo->exec("
    CREATE TABLE IF NOT EXISTS app_users (
        id           INT AUTO_INCREMENT PRIMARY KEY,
        mobile       VARCHAR(15) NOT NULL UNIQUE,
        name         VARCHAR(100) DEFAULT NULL,
        dob          DATE DEFAULT NULL,
        city         VARCHAR(100) DEFAULT NULL,
        profile_pic  VARCHAR(255) DEFAULT NULL,
        batting_style VARCHAR(50) DEFAULT 'Right Hand Bat',
        bowling_style VARCHAR(50) DEFAULT 'Right Arm Medium',
        role          VARCHAR(50) DEFAULT 'All-Rounder',
        jersey_number VARCHAR(10) DEFAULT NULL,
        preferred_format VARCHAR(20) DEFAULT NULL,
        fcm_token    VARCHAR(255) DEFAULT NULL,
        language     VARCHAR(10) DEFAULT 'en',
        is_blocked   TINYINT DEFAULT 0,
        profile_complete TINYINT DEFAULT 0,
        created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_login   DATETIME DEFAULT NULL,
        UNIQUE KEY uq_app_users_mob (mobile)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS api_tokens (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        user_id    INT NOT NULL,
        token      VARCHAR(255) NOT NULL UNIQUE,
        expires_at DATETIME DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_tokens_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");


// ── Find or create app_user ───────────────────────────────────────────────────
$userStmt = $pdo->prepare("SELECT * FROM app_users WHERE mobile = ?");
$userStmt->execute([$mobile]);
$user = $userStmt->fetch();

$isNewUser = false;
if (!$user) {
    // New user — register with mobile only
    $ins = $pdo->prepare("INSERT INTO app_users (mobile) VALUES (?)");
    $ins->execute([$mobile]);
    $userId    = (int)$pdo->lastInsertId();
    $isNewUser = true;
    $user = [
        'id'               => $userId,
        'mobile'           => $mobile,
        'name'             => null,
        'profile_complete' => 0,
    ];
} else {
    // Existing user — check if blocked
    if ((int)($user['is_blocked'] ?? 0) === 1) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Your account has been suspended. Contact support.']);
        exit;
    }
    $userId = (int)$user['id'];
}

// ── Update last login ─────────────────────────────────────────────────────────
$now = date('Y-m-d H:i:s');
$pdo->prepare("UPDATE app_users SET last_login=? WHERE id=?")->execute([$now, $userId]);

// ── Generate secure API token (valid 30 days) ─────────────────────────────────
$token   = bin2hex(random_bytes(40)); // 80-char hex token
$expires = date('Y-m-d H:i:s', strtotime('+30 days'));

// Delete old tokens for this user (keep DB clean)
$pdo->prepare("DELETE FROM api_tokens WHERE user_id=?")->execute([$userId]);

// Insert new token
$pdo->prepare("INSERT INTO api_tokens (user_id, token, expires_at) VALUES (?,?,?)")
    ->execute([$userId, $token, $expires]);

// ── Build response ────────────────────────────────────────────────────────────
$userOut = [
    'id'               => (int)$user['id'],
    'mobile'           => $user['mobile'],
    'name'             => $user['name'] ?? null,
    'city'             => $user['city'] ?? null,
    'profile_pic'      => $user['profile_pic'] ?? null,
    'batting_style'    => $user['batting_style'] ?? null,
    'bowling_style'    => $user['bowling_style'] ?? null,
    'role'             => $user['role'] ?? null,
    'jersey_number'    => $user['jersey_number'] ?? null,
    'profile_complete' => (int)($user['profile_complete'] ?? 0),
    'language'         => $user['language'] ?? 'en',
];

echo json_encode([
    'success'      => true,
    'message'      => $isNewUser ? 'Welcome! Please complete your profile.' : 'Login successful.',
    'token'        => $token,
    'token_expires'=> $expires,
    'user'         => $userOut,
    'is_new_user'  => $isNewUser,
]);
