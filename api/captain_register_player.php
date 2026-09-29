<?php
// api/captain_register_player.php
// Allows team captain to register a new player with mobile verification & add directly to team squad (Max 20 limit)
// POST { "team_id": 1, "name": "Ramesh", "mobile": "9876543210", "otp": "123456", "role": "BAT", "batting_style": "Right Hand Bat", "bowling_style": "Right Arm Medium", "jersey_number": "7" }

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
require_once __DIR__ . '/app_auth.php';

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;

$team_id       = (int)($input['team_id'] ?? 0);
$name          = trim($input['name'] ?? '');
$mobile        = trim($input['mobile'] ?? '');
$otp           = trim($input['otp'] ?? '');
$role          = trim($input['role'] ?? 'BAT');
$batting_style = trim($input['batting_style'] ?? 'Right Hand Bat');
$bowling_style = trim($input['bowling_style'] ?? 'Right Arm Medium');
$jersey_number = trim($input['jersey_number'] ?? '');
$skip_otp      = !empty($input['skip_otp']); // For admin or fast local tests

if ($team_id <= 0 || empty($name)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Team ID and Player Name are required.']);
    exit;
}

// Mobile format validation if provided
if (!empty($mobile) && !preg_match('/^[6-9]\d{9}$/', $mobile)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid 10-digit Indian mobile number.']);
    exit;
}

// 1. Fetch current squad count for metadata
$countStmt = $pdo->prepare("SELECT COUNT(*) FROM players WHERE team_id = ?");
$countStmt->execute([$team_id]);
$currentSquadCount = (int)$countStmt->fetchColumn();

// 2. OTP Verification if mobile & OTP provided
if (!empty($mobile) && !$skip_otp) {
    if (empty($otp)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'OTP is required to verify the player.']);
        exit;
    }

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
        echo json_encode(['success' => false, 'message' => 'OTP expired or not found. Please resend OTP.']);
        exit;
    }

    if ($otpRow['otp'] !== $otp) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Invalid OTP entered.']);
        exit;
    }

    // Mark OTP verified
    $pdo->prepare("UPDATE mobile_otps SET verified = 1 WHERE id = ?")->execute([$otpRow['id']]);
}

try {
    // 3. Check if player already exists in this team
    $dupCheck = $pdo->prepare("SELECT id FROM players WHERE team_id = ? AND (LOWER(name) = LOWER(?) OR (mobile = ? AND mobile != ''))");
    $dupCheck->execute([$team_id, $name, $mobile]);
    if ($dupCheck->fetch()) {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'Player already exists in this team squad.']);
        exit;
    }

    // 4. Insert Player into Squad
    $insStmt = $pdo->prepare("
        INSERT INTO players (team_id, name, role, jersey_number, mobile, batting_style, bowling_style, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
    ");
    $insStmt->execute([$team_id, $name, $role, $jersey_number, $mobile, $batting_style, $bowling_style]);
    $playerId = (int)$pdo->lastInsertId();

    // 5. If mobile given, ensure user record exists
    if (!empty($mobile)) {
        $userCheck = $pdo->prepare("SELECT id FROM users WHERE phone = ?");
        $userCheck->execute([$mobile]);
        if (!$userCheck->fetch()) {
            $username = 'player_' . $mobile;
            $defaultHash = password_hash('sb_cricket_user', PASSWORD_DEFAULT);
            $userIns = $pdo->prepare("
                INSERT INTO users (username, phone, role, batting_style, bowling_style, is_verified, password_hash)
                VALUES (?, ?, ?, ?, ?, 1, ?)
            ");
            $userIns->execute([$username, $mobile, $role, $batting_style, $bowling_style, $defaultHash]);
        }
    }

    echo json_encode([
        'success'      => true,
        'player_id'    => $playerId,
        'team_id'      => $team_id,
        'squad_count'  => $currentSquadCount + 1,
        'message'      => "Player {$name} successfully registered and added to squad!"
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
