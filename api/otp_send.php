<?php
// api/otp_send.php
// Sends OTP via ping4sms SMS API for mobile login (Pure MySQL)
// POST { "mobile": "9876543210" }

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

// ─── ping4sms Config ──────────────────────────────────────────────────────────
define('SMS_API_KEY',    'e1fc54301c0da93b95d3502a3151f420');
define('SMS_SENDER',     'ASTELV');
define('SMS_ROUTE',      '4');
define('SMS_TEMPLATE_ID','1677100000000387344');
define('SMS_API_URL',    'https://site.ping4sms.com/api/smsapi');
// ─────────────────────────────────────────────────────────────────────────────

// Read JSON body
$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$mobile = trim($body['mobile'] ?? '');

// Validate mobile number (10 digits India)
if (!preg_match('/^[6-9]\d{9}$/', $mobile)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid mobile number. Enter 10-digit Indian mobile number.']);
    exit;
}

// ── Ensure mobile_otps table exists (MySQL) ──────────────────────────────────
$pdo->exec("
    CREATE TABLE IF NOT EXISTS mobile_otps (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        mobile     VARCHAR(15) NOT NULL,
        otp        VARCHAR(10) NOT NULL,
        attempts   TINYINT NOT NULL DEFAULT 0,
        expires_at DATETIME NOT NULL,
        verified   TINYINT NOT NULL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_otps_mobile (mobile)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
");

// ── Rate limiting: max 3 OTP requests per 10 minutes per number ──────────────
$tenMinsAgo = date('Y-m-d H:i:s', strtotime('-10 minutes'));
$rateStmt = $pdo->prepare("
    SELECT COUNT(*) as cnt FROM mobile_otps
    WHERE mobile = ? AND created_at >= ?
");
$rateStmt->execute([$mobile, $tenMinsAgo]);
$rateRow = $rateStmt->fetch();
if ((int)($rateRow['cnt'] ?? 0) >= 3) {
    http_response_code(429);
    echo json_encode(['success' => false, 'message' => 'Too many OTP requests. Please wait 10 minutes and try again.']);
    exit;
}

// ── Generate 6-digit OTP ─────────────────────────────────────────────────────
$otp     = str_pad(random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
$expires = date('Y-m-d H:i:s', strtotime('+10 minutes'));

// ── Store OTP in DB (expires in 10 minutes) ───────────────────────────────────
$ins = $pdo->prepare("
    INSERT INTO mobile_otps (mobile, otp, expires_at, verified, attempts)
    VALUES (?, ?, ?, 0, 0)
");
$ins->execute([$mobile, $otp, $expires]);

// ── Send SMS via ping4sms ─────────────────────────────────────────────────────
$smsText = "Dear Customer,Your OTP for login on ASTRO ELEVEN is {$otp}.Do not share it with any One. https://astroeleven.com/";

$smsUrl = SMS_API_URL . '?' . http_build_query([
    'key'        => SMS_API_KEY,
    'route'      => SMS_ROUTE,
    'sender'     => SMS_SENDER,
    'number'     => $mobile,
    'sms'        => $smsText,
    'templateid' => SMS_TEMPLATE_ID,
]);

$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL            => $smsUrl,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 10,
    CURLOPT_SSL_VERIFYPEER => true,
]);
$smsResponse = curl_exec($ch);
$curlError   = curl_error($ch);
$httpCode    = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

// Log SMS response for debugging
error_log("ping4sms [mobile={$mobile}]: HTTP {$httpCode} | {$smsResponse}");

if ($curlError || $httpCode !== 200) {
    $pdo->prepare("DELETE FROM mobile_otps WHERE mobile=? AND otp=?")->execute([$mobile, $otp]);
    http_response_code(502);
    echo json_encode([
        'success' => false,
        'message' => 'SMS sending failed. Please try again.',
        'debug'   => $curlError ?: "HTTP {$httpCode}"
    ]);
    exit;
}

// Check ping4sms response body for error indicators
$smsResponseLower = strtolower((string)$smsResponse);
if (
    str_contains($smsResponseLower, 'error') ||
    str_contains($smsResponseLower, 'fail')  ||
    str_contains($smsResponseLower, 'invalid')
) {
    $pdo->prepare("DELETE FROM mobile_otps WHERE mobile=? AND otp=?")->execute([$mobile, $otp]);
    http_response_code(502);
    echo json_encode([
        'success' => false,
        'message' => 'SMS delivery failed. Check the mobile number.',
        'gateway' => $smsResponse
    ]);
    exit;
}

// ── Success ───────────────────────────────────────────────────────────────────
echo json_encode([
    'success'    => true,
    'message'    => "OTP sent to +91 {$mobile}. Valid for 10 minutes.",
    'mobile'     => $mobile,
    'expires_in' => 600,
]);
