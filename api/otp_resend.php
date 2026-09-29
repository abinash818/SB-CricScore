<?php
// api/otp_resend.php
// Resend OTP — invalidates previous and sends fresh OTP
// POST { "mobile": "9876543210" }

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';

$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$mobile = trim($body['mobile'] ?? '');

if (!preg_match('/^[6-9]\d{9}$/', $mobile)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid mobile number.']);
    exit;
}

// Invalidate all previous unverified OTPs for this mobile
$pdo->prepare("UPDATE mobile_otps SET verified=2 WHERE mobile=? AND verified=0")->execute([$mobile]);

// Forward to otp_send logic — reuse via include
// (We re-implement here to avoid require_once conflicts)
define('SMS_API_KEY',    'e1fc54301c0da93b95d3502a3151f420');
define('SMS_SENDER',     'ASTELV');
define('SMS_ROUTE',      '4');
define('SMS_TEMPLATE_ID','1677100000000387344');
define('SMS_API_URL',    'https://site.ping4sms.com/api/smsapi');

$driver  = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
$otp     = str_pad(random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
$expires = date('Y-m-d H:i:s', strtotime('+10 minutes'));

$pdo->prepare("INSERT INTO mobile_otps (mobile, otp, expires_at, verified, attempts) VALUES (?,?,?,0,0)")
    ->execute([$mobile, $otp, $expires]);

$smsText = "Dear Customer,Your OTP for login on ASTRO ELEVEN is {$otp}.Do not share it with any One. https://astroeleven.com/";
$smsUrl  = SMS_API_URL . '?' . http_build_query([
    'key'        => SMS_API_KEY,
    'route'      => SMS_ROUTE,
    'sender'     => SMS_SENDER,
    'number'     => $mobile,
    'sms'        => $smsText,
    'templateid' => SMS_TEMPLATE_ID,
]);

$ch = curl_init();
curl_setopt_array($ch, [CURLOPT_URL => $smsUrl, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10]);
$smsResponse = curl_exec($ch);
$curlError   = curl_error($ch);
$httpCode    = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($curlError || $httpCode !== 200) {
    http_response_code(502);
    echo json_encode(['success' => false, 'message' => 'SMS sending failed. Try again.']);
    exit;
}

echo json_encode([
    'success'    => true,
    'message'    => "New OTP sent to +91 {$mobile}. Valid for 10 minutes.",
    'expires_in' => 600,
]);
