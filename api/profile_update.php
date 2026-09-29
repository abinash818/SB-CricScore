<?php
// api/profile_update.php
// POST /api/profile_update.php (Requires Authorization: Bearer <token>)
// Updates user profile details + optional photo upload with GD image compression

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

$user = app_require_auth($pdo);
$userId = (int)$user['id'];

// Can accept either JSON body or $_POST (multipart form data for image upload)
$isJson = isset($_SERVER['CONTENT_TYPE']) && str_contains(strtolower($_SERVER['CONTENT_TYPE']), 'application/json');
$input  = $isJson ? (json_decode(file_get_contents('php://input'), true) ?? []) : $_POST;

$name            = isset($input['name']) ? trim($input['name']) : $user['name'];
$dob             = isset($input['dob']) ? trim($input['dob']) : $user['dob'];
$city            = isset($input['city']) ? trim($input['city']) : $user['city'];
$batting_style   = isset($input['batting_style']) ? trim($input['batting_style']) : $user['batting_style'];
$bowling_style   = isset($input['bowling_style']) ? trim($input['bowling_style']) : $user['bowling_style'];
$role            = isset($input['role']) ? trim($input['role']) : $user['role'];
$jersey_number   = isset($input['jersey_number']) ? trim($input['jersey_number']) : $user['jersey_number'];
$preferred_format= isset($input['preferred_format']) ? trim($input['preferred_format']) : $user['preferred_format'];
$language        = isset($input['language']) ? trim($input['language']) : $user['language'];
$fcm_token       = isset($input['fcm_token']) ? trim($input['fcm_token']) : $user['fcm_token'];

$profilePicPath  = $user['profile_pic'];

// ── Profile Photo Upload Handling (Hostinger Inode & Size Safe GD Compression) ──
if (isset($_FILES['profile_pic']) && $_FILES['profile_pic']['error'] === UPLOAD_ERR_OK) {
    $fileTmp  = $_FILES['profile_pic']['tmp_name'];
    $fileName = $_FILES['profile_pic']['name'];
    $ext      = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));

    $allowedExts = ['jpg', 'jpeg', 'png', 'webp'];
    if (in_array($ext, $allowedExts)) {
        $uploadDir = __DIR__ . '/../uploads/players/';
        if (!is_dir($uploadDir)) {
            @mkdir($uploadDir, 0775, true);
        }

        // Generate unique filename
        $newFilename = 'app_user_' . $userId . '_' . time() . '.jpg';
        $destination = $uploadDir . $newFilename;

        // Compress and resize image using GD
        $img = null;
        if ($ext === 'png') {
            $img = @imagecreatefrompng($fileTmp);
        } else if ($ext === 'webp') {
            $img = @imagecreatefromwebp($fileTmp);
        } else {
            $img = @imagecreatefromjpeg($fileTmp);
        }

        if ($img) {
            $origW = imagesx($img);
            $origH = imagesy($img);

            $maxW = 400;
            $maxH = 400;

            if ($origW > $maxW || $origH > $maxH) {
                $ratio = min($maxW / $origW, $maxH / $origH);
                $newW  = (int)($origW * $ratio);
                $newH  = (int)($origH * $ratio);

                $resized = imagecreatetruecolor($newW, $newH);
                imagecopyresampled($resized, $img, 0, 0, 0, 0, $newW, $newH, $origW, $origH);
                imagedestroy($img);
                $img = $resized;
            }

            // Save compressed JPEG (Quality 80 ~ 25-35KB)
            imagejpeg($img, $destination, 80);
            imagedestroy($img);

            // Unlink old photo if exists
            if ($profilePicPath && file_exists(__DIR__ . '/../' . $profilePicPath)) {
                @unlink(__DIR__ . '/../' . $profilePicPath);
            }

            $profilePicPath = 'uploads/players/' . $newFilename;
        }
    }
}

// ── Check if profile is now complete ──
$profileComplete = (!empty($name) && !empty($city)) ? 1 : 0;

// ── Database Update ──
$stmt = $pdo->prepare("
    UPDATE app_users SET
        name = ?,
        dob = ?,
        city = ?,
        profile_pic = ?,
        batting_style = ?,
        bowling_style = ?,
        role = ?,
        jersey_number = ?,
        preferred_format = ?,
        language = ?,
        fcm_token = ?,
        profile_complete = ?
    WHERE id = ?
");

$stmt->execute([
    $name,
    $dob,
    $city,
    $profilePicPath,
    $batting_style,
    $bowling_style,
    $role,
    $jersey_number,
    $preferred_format,
    $language,
    $fcm_token,
    $profileComplete,
    $userId
]);

// Fetch updated user details
$fetchStmt = $pdo->prepare("SELECT * FROM app_users WHERE id = ?");
$fetchStmt->execute([$userId]);
$updatedUser = $fetchStmt->fetch();

echo json_encode([
    'success' => true,
    'message' => 'Profile updated successfully.',
    'user'    => [
        'id'               => (int)$updatedUser['id'],
        'mobile'           => $updatedUser['mobile'],
        'name'             => $updatedUser['name'],
        'dob'              => $updatedUser['dob'],
        'city'             => $updatedUser['city'],
        'profile_pic'      => $updatedUser['profile_pic'],
        'batting_style'    => $updatedUser['batting_style'],
        'bowling_style'    => $updatedUser['bowling_style'],
        'role'             => $updatedUser['role'],
        'jersey_number'    => $updatedUser['jersey_number'],
        'preferred_format' => $updatedUser['preferred_format'],
        'language'         => $updatedUser['language'],
        'profile_complete' => (int)$updatedUser['profile_complete'],
    ]
]);
