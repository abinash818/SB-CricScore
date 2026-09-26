<?php
// api/player_register.php - Dedicated Team Player Registration API
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';

header('Content-Type: application/json');

$action = $_GET['action'] ?? $_POST['action'] ?? 'add';

// 1. LIST SQUAD PLAYERS FOR A TEAM
if ($action === 'list') {
    $teamId = (int)($_GET['team_id'] ?? 0);
    if ($teamId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Team ID required']);
        exit;
    }

    $tStmt = $pdo->prepare("SELECT t.*, tr.name as tournament_name FROM teams t JOIN tournaments tr ON t.tournament_id = tr.id WHERE t.id = ?");
    $tStmt->execute([$teamId]);
    $team = $tStmt->fetch(PDO::FETCH_ASSOC);
    if (!$team) {
        http_response_code(404);
        echo json_encode(['error' => 'Team not found']);
        exit;
    }

    $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ? ORDER BY is_captain DESC, id ASC");
    $pStmt->execute([$teamId]);
    $players = $pStmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'ok' => true,
        'team' => $team,
        'players' => $players,
        'count' => count($players)
    ]);
    exit;
}

// 2. REGISTER / ADD NEW PLAYER
if ($action === 'add') {
    $teamId = (int)($_POST['team_id'] ?? 0);
    $name = trim($_POST['name'] ?? '');
    $role = strtoupper(trim($_POST['role'] ?? 'BAT'));
    $jersey = trim($_POST['jersey_number'] ?? '');
    $isCaptain = !empty($_POST['is_captain']) ? 1 : 0;
    $mobile = trim($_POST['mobile'] ?? '');
    $dob = trim($_POST['dob'] ?? '');
    $tob = trim($_POST['tob'] ?? '');
    $pob = trim($_POST['pob'] ?? '');
    $battingStyle = trim($_POST['batting_style'] ?? 'Right Hand Bat');
    $bowlingStyle = trim($_POST['bowling_style'] ?? 'Right Arm Medium');

    if ($teamId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid or missing team ID']);
        exit;
    }

    if (empty($name)) {
        http_response_code(400);
        echo json_encode(['error' => 'Player Name is required']);
        exit;
    }

    // Verify team exists
    $tStmt = $pdo->prepare("SELECT id, tournament_id FROM teams WHERE id = ?");
    $tStmt->execute([$teamId]);
    $team = $tStmt->fetch(PDO::FETCH_ASSOC);
    if (!$team) {
        http_response_code(404);
        echo json_encode(['error' => 'Selected Team does not exist']);
        exit;
    }

    // Check duplicate name in team
    $chk = $pdo->prepare("SELECT id FROM players WHERE team_id = ? AND LOWER(TRIM(name)) = ?");
    $chk->execute([$teamId, strtolower($name)]);
    if ($chk->fetch()) {
        http_response_code(400);
        echo json_encode(['error' => "Player '{$name}' is already registered in this team!"]);
        exit;
    }

    // Check duplicate mobile in team (if mobile provided)
    if (!empty($mobile)) {
        $chkMobile = $pdo->prepare("SELECT id, name FROM players WHERE team_id = ? AND mobile = ?");
        $chkMobile->execute([$teamId, $mobile]);
        $existMobile = $chkMobile->fetch(PDO::FETCH_ASSOC);
        if ($existMobile) {
            http_response_code(400);
            echo json_encode(['error' => "Mobile number '{$mobile}' is already registered with player '{$existMobile['name']}' in this team!"]);
            exit;
        }
    }

    // Handle Photo Upload with Auto-Compression & Resizing
    $profilePic = null;
    $uploadDir = __DIR__ . '/../uploads/players/';
    if (!file_exists($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    if (isset($_FILES['photo']) && $_FILES['photo']['error'] === UPLOAD_ERR_OK) {
        $tmp = $_FILES['photo']['tmp_name'];
        $origName = $_FILES['photo']['name'];
        $ext = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
        $allowed = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

        if (in_array($ext, $allowed)) {
            $cleanName = preg_replace('/[^a-zA-Z0-9]/', '_', strtolower($name));
            $filename = 'player_' . $cleanName . '_' . time() . '_' . rand(100, 999) . '.jpg';
            $targetPath = $uploadDir . $filename;

            // Auto-compress & resize avatar to max 400x400 (keeps file size under 50KB)
            $srcImg = null;
            if ($ext === 'png' && function_exists('imagecreatefrompng')) {
                $srcImg = @imagecreatefrompng($tmp);
            } elseif ($ext === 'webp' && function_exists('imagecreatefromwebp')) {
                $srcImg = @imagecreatefromwebp($tmp);
            } elseif (function_exists('imagecreatefromjpeg')) {
                $srcImg = @imagecreatefromjpeg($tmp);
            }

            if ($srcImg) {
                $origW = imagesx($srcImg);
                $origH = imagesy($srcImg);
                $maxDim = 400;

                // Calculate scaled dimensions
                if ($origW > $maxDim || $origH > $maxDim) {
                    if ($origW > $origH) {
                        $newW = $maxDim;
                        $newH = (int)($origH * ($maxDim / $origW));
                    } else {
                        $newH = $maxDim;
                        $newW = (int)($origW * ($maxDim / $origH));
                    }
                } else {
                    $newW = $origW;
                    $newH = $origH;
                }

                $dstImg = imagecreatetruecolor($newW, $newH);
                imagecopyresampled($dstImg, $srcImg, 0, 0, 0, 0, $newW, $newH, $origW, $origH);
                imagejpeg($dstImg, $targetPath, 82);
                imagedestroy($srcImg);
                imagedestroy($dstImg);
                $profilePic = 'uploads/players/' . $filename;
            } else {
                // Fallback direct copy if GD processing not possible
                if (move_uploaded_file($tmp, $targetPath)) {
                    $profilePic = 'uploads/players/' . $filename;
                }
            }
        }
    }

    // If captain is chosen, reset other captains in team
    if ($isCaptain === 1) {
        $rCap = $pdo->prepare("UPDATE players SET is_captain = 0 WHERE team_id = ?");
        $rCap->execute([$teamId]);
    }

    $ins = $pdo->prepare("
        INSERT INTO players (team_id, name, role, jersey_number, is_captain, profile_pic, mobile, dob, tob, pob, batting_style, bowling_style)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $ins->execute([
        $teamId,
        $name,
        $role,
        $jersey,
        $isCaptain,
        $profilePic,
        $mobile,
        $dob,
        $tob,
        $pob,
        $battingStyle,
        $bowlingStyle
    ]);

    $newId = (int)$pdo->lastInsertId();

    echo json_encode([
        'ok' => true,
        'player_id' => $newId,
        'message' => "Player '{$name}' registered successfully!",
        'player' => [
            'id' => $newId,
            'name' => $name,
            'role' => $role,
            'jersey_number' => $jersey,
            'is_captain' => $isCaptain,
            'profile_pic' => $profilePic,
            'mobile' => $mobile,
            'dob' => $dob,
            'tob' => $tob,
            'pob' => $pob,
            'batting_style' => $battingStyle,
            'bowling_style' => $bowlingStyle
        ]
    ]);
    exit;
}

// 3. DELETE PLAYER
if ($action === 'delete') {
    $playerId = (int)($_POST['player_id'] ?? 0);
    if ($playerId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Player ID required']);
        exit;
    }

    // Delete photo file if exists
    $pStmt = $pdo->prepare("SELECT profile_pic FROM players WHERE id = ?");
    $pStmt->execute([$playerId]);
    $p = $pStmt->fetch(PDO::FETCH_ASSOC);
    if ($p && !empty($p['profile_pic'])) {
        $picPath = __DIR__ . '/../' . $p['profile_pic'];
        if (file_exists($picPath)) {
            @unlink($picPath);
        }
    }

    $del = $pdo->prepare("DELETE FROM players WHERE id = ?");
    $del->execute([$playerId]);

    echo json_encode(['ok' => true, 'message' => 'Player removed successfully']);
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'Invalid action']);
