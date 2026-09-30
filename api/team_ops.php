<?php
// api/team_ops.php
// Team Management & Squad Builder API
// GET  /api/team_ops.php?action=list
// GET  /api/team_ops.php?action=get&team_id=X
// POST /api/team_ops.php?action=create
// POST /api/team_ops.php?action=add_player
// POST /api/team_ops.php?action=clone

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$action = $_GET['action'] ?? ($_POST['action'] ?? 'list');

// ── 1. LIST TEAMS ───────────────────────────────────────────────────────────
if ($action === 'list') {
    $tid = (int)($_GET['tournament_id'] ?? 0);
    $search = trim($_GET['q'] ?? '');

    $where = [];
    $params = [];

    if ($tid > 0) {
        $where[] = "tournament_id = ?";
        $params[] = $tid;
    }
    if (!empty($search)) {
        $where[] = "(LOWER(name) LIKE ? OR LOWER(short_name) LIKE ?)";
        $params[] = '%' . strtolower($search) . '%';
        $params[] = '%' . strtolower($search) . '%';
    }

    $sql = "SELECT t.*, (SELECT COUNT(*) FROM players p WHERE p.team_id = t.id) as player_count FROM teams t";
    if (!empty($where)) {
        $sql .= " WHERE " . implode(' AND ', $where);
    }
    $sql .= " ORDER BY t.id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $teams = $stmt->fetchAll();

    echo json_encode(['success' => true, 'teams' => $teams]);
    exit;
}

// ── 2. GET TEAM DETAILS & SQUAD ──────────────────────────────────────────────
if ($action === 'get') {
    $teamId = (int)($_GET['team_id'] ?? 0);
    if ($teamId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'team_id is required']);
        exit;
    }

    $tStmt = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
    $tStmt->execute([$teamId]);
    $team = $tStmt->fetch();

    if (!$team) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Team not found']);
        exit;
    }

    // Squad Players
    $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ? ORDER BY is_captain DESC, id ASC");
    $pStmt->execute([$teamId]);
    $players = $pStmt->fetchAll();

    echo json_encode([
        'success' => true,
        'team'    => $team,
        'squad'   => $players,
    ]);
    exit;
}

// ── 3. CREATE TEAM ───────────────────────────────────────────────────────────
if ($action === 'create') {
    $input     = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $tid       = (int)($input['tournament_id'] ?? 1);
    $name      = trim($input['name'] ?? '');
    $shortName = trim($input['short_name'] ?? '');
    $icon      = trim($input['icon'] ?? 'shield');

    if (empty($name)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Team name is required']);
        exit;
    }

    if (empty($shortName)) {
        $words = explode(' ', $name);
        $shortName = strtoupper(substr($name, 0, 3));
        if (count($words) >= 2) {
            $shortName = strtoupper(substr($words[0], 0, 1) . substr($words[1], 0, 1));
        }
    }

    $stmt = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
    $stmt->execute([$tid, $name, $shortName, $icon]);
    $teamId = (int)$pdo->lastInsertId();

    echo json_encode([
        'success'   => true,
        'message'   => 'Team created successfully',
        'team_id'   => $teamId,
        'name'      => $name,
        'short_name'=> $shortName
    ]);
    exit;
}

// ── 4. ADD PLAYER TO SQUAD ───────────────────────────────────────────────────
if ($action === 'add_player') {
    $input  = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $teamId = (int)($input['team_id'] ?? 0);
    $name   = trim($input['name'] ?? '');
    $role   = trim($input['role'] ?? 'BAT');
    $jersey = trim($input['jersey_number'] ?? '');
    $isCapt = (int)($input['is_captain'] ?? 0);
    $mobile = trim($input['mobile'] ?? '');
    $batStyle = trim($input['batting_style'] ?? 'Right Hand Bat');
    $bowlStyle = trim($input['bowling_style'] ?? 'Right Arm Medium');

    if ($teamId <= 0 || empty($name)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Team ID and Player Name are required']);
        exit;
    }

    if ($isCapt === 1) {
        // Unmark other captains in this team
        $pdo->prepare("UPDATE players SET is_captain=0 WHERE team_id=?")->execute([$teamId]);
    }

    $stmt = $pdo->prepare("INSERT INTO players (team_id, name, role, jersey_number, is_captain, mobile, batting_style, bowling_style) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$teamId, $name, $role, $jersey, $isCapt, $mobile, $batStyle, $bowlStyle]);
    $playerId = (int)$pdo->lastInsertId();

    echo json_encode([
        'success'   => true,
        'message'   => 'Player added to squad',
        'player_id' => $playerId,
    ]);
    exit;
}

// ── 5. CLONE SQUAD FEATURE ────────────────────────────────────────────────────
if ($action === 'clone') {
    $input            = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $targetTournId    = (int)($input['target_tournament_id'] ?? 1);
    $sourceTeamId     = (int)($input['source_team_id'] ?? 0);

    if ($sourceTeamId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'source_team_id is required']);
        exit;
    }

    $st = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
    $st->execute([$sourceTeamId]);
    $srcTeam = $st->fetch();

    if (!$srcTeam) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Source team not found']);
        exit;
    }

    // Insert new team into target tournament
    $insTeam = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
    $insTeam->execute([$targetTournId, $srcTeam['name'], $srcTeam['short_name'], $srcTeam['icon']]);
    $newTeamId = (int)$pdo->lastInsertId();

    // Copy players
    $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ?");
    $pStmt->execute([$sourceTeamId]);
    $srcPlayers = $pStmt->fetchAll();

    $insPlayer = $pdo->prepare("
        INSERT INTO players (team_id, name, role, jersey_number, is_captain, profile_pic, mobile, dob, batting_style, bowling_style)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    $copiedCount = 0;
    foreach ($srcPlayers as $p) {
        $insPlayer->execute([
            $newTeamId,
            $p['name'],
            $p['role'] ?? 'BAT',
            $p['jersey_number'] ?? '',
            $p['is_captain'] ?? 0,
            $p['profile_pic'] ?? null,
            $p['mobile'] ?? '',
            $p['dob'] ?? '',
            $p['batting_style'] ?? 'Right Hand Bat',
            $p['bowling_style'] ?? 'Right Arm Medium',
        ]);
        $copiedCount++;
    }

    echo json_encode([
        'success'     => true,
        'message'     => "Cloned team '{$srcTeam['name']}' with {$copiedCount} players",
        'new_team_id' => $newTeamId,
    ]);
    exit;
}

// ── 6. CHECK TEAM NAME AVAILABILITY ─────────────────────────────────────────
if ($action === 'check_name') {
    $name = trim($_GET['name'] ?? ($_POST['name'] ?? ''));
    if (empty($name) || strlen($name) < 2) {
        echo json_encode(['success' => true, 'available' => false, 'message' => 'Please enter at least 2 characters']);
        exit;
    }

    $chk = $pdo->prepare("SELECT id, name, city FROM teams WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) LIMIT 1");
    $chk->execute([$name]);
    $existing = $chk->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        echo json_encode([
            'success'   => true,
            'available' => false,
            'name'      => $name,
            'message'   => "Team name '{$existing['name']}' is already taken!"
        ]);
    } else {
        echo json_encode([
            'success'   => true,
            'available' => true,
            'name'      => $name,
            'message'   => "Team name is available! ✅"
        ]);
    }
    exit;
}

// ── 7. CREATE USER TEAM (Mobile App Self-Service with Auto Captain) ─────────
if ($action === 'create_user_team') {
    $input     = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $name      = trim($input['name'] ?? '');
    $shortName = trim($input['short_name'] ?? '');
    $city      = trim($input['city'] ?? '');
    $icon      = trim($input['icon'] ?? 'shield');
    $ownerId   = (int)($input['owner_id'] ?? 0);
    $tournId   = (int)($input['tournament_id'] ?? 1);

    // Creator / Captain fields
    $addCaptain      = isset($input['add_captain']) ? (bool)$input['add_captain'] : true;
    $creatorName     = trim($input['creator_name'] ?? '');
    $creatorMobile   = trim($input['creator_mobile'] ?? '');
    $creatorRole     = trim($input['creator_role'] ?? 'All-Rounder');
    $creatorBatStyle = trim($input['creator_batting_style'] ?? 'Right Hand Bat');
    $creatorBowlStyle= trim($input['creator_bowling_style'] ?? 'Right Arm Medium');
    $creatorJersey   = trim($input['creator_jersey'] ?? '7');
    $creatorPhoto    = trim($input['creator_profile_pic'] ?? '');

    $currentUser = app_optional_auth($pdo);
    if ($currentUser) {
        if ($ownerId <= 0) $ownerId = (int)$currentUser['id'];
        if (empty($creatorName)) $creatorName = $currentUser['name'] ?? '';
        if (empty($creatorMobile)) $creatorMobile = $currentUser['phone'] ?? '';
        if (empty($creatorPhoto) && !empty($currentUser['profile_pic'])) $creatorPhoto = $currentUser['profile_pic'];
    }

    if (empty($name)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Team name is required.']);
        exit;
    }

    // Check availability
    $chk = $pdo->prepare("SELECT id FROM teams WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))");
    $chk->execute([$name]);
    if ($chk->fetch()) {
        http_response_code(409);
        echo json_encode(['success' => false, 'is_taken' => true, 'message' => "Team name '{$name}' is already taken. Please choose another name."]);
        exit;
    }

    if (empty($shortName)) {
        $words = explode(' ', $name);
        $shortName = strtoupper(substr($name, 0, 3));
        if (count($words) >= 2) {
            $shortName = strtoupper(substr($words[0], 0, 1) . substr($words[1], 0, 1));
        }
    }

    try {
        $stmt = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, city, icon, owner_id) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$tournId, $name, $shortName, $city, $icon, ($ownerId > 0 ? $ownerId : null)]);
        $teamId = (int)$pdo->lastInsertId();

        // Automatically add Creator as Captain in Squad if enabled or creator info available
        $captainPlayerId = 0;
        if ($addCaptain && (!empty($creatorName) || !empty($creatorMobile))) {
            $captainName = !empty($creatorName) ? $creatorName : 'Team Captain';
            
            $pStmt = $pdo->prepare("
                INSERT INTO players (team_id, name, role, jersey_number, is_captain, mobile, batting_style, bowling_style, profile_pic)
                VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?)
            ");
            $pStmt->execute([
                $teamId,
                $captainName,
                $creatorRole,
                $creatorJersey,
                $creatorMobile,
                $creatorBatStyle,
                $creatorBowlStyle,
                !empty($creatorPhoto) ? $creatorPhoto : null
            ]);
            $captainPlayerId = (int)$pdo->lastInsertId();
        }

        echo json_encode([
            'success'           => true,
            'message'           => "Team '{$name}' created with you as Captain / Owner! 🚀",
            'team_id'           => $teamId,
            'name'              => $name,
            'short_name'        => $shortName,
            'city'              => $city,
            'icon'              => $icon,
            'captain_player_id' => $captainPlayerId,
        ]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to create team: ' . $e->getMessage()]);
    }
    exit;
}

// ── 8. GET MY TEAMS (User's Owned Teams & Squads) ───────────────────────────
if ($action === 'my_teams') {
    $ownerId = (int)($_GET['owner_id'] ?? ($_GET['user_id'] ?? 0));
    $playerId = (int)($_GET['player_id'] ?? 0);
    $mobile = trim($_GET['mobile'] ?? '');
    $playerName = trim($_GET['player_name'] ?? '');

    $currentUser = app_optional_auth($pdo);
    if ($currentUser) {
        if ($ownerId <= 0) $ownerId = (int)$currentUser['id'];
        if (empty($mobile)) $mobile = $currentUser['phone'] ?? '';
        if (empty($playerName)) $playerName = $currentUser['name'] ?? '';
    }

    $whereClauses = [];
    $params = [];

    // 1. Teams created by this user
    if ($ownerId > 0) {
        $whereClauses[] = "t.owner_id = ?";
        $params[] = $ownerId;
    }

    // 2. Teams where this player is registered in squad
    if ($playerId > 0) {
        $whereClauses[] = "t.id IN (SELECT team_id FROM players WHERE id = ?)";
        $params[] = $playerId;
    }
    if (!empty($mobile)) {
        $whereClauses[] = "t.id IN (SELECT team_id FROM players WHERE mobile = ?)";
        $params[] = $mobile;
    }
    if (!empty($playerName)) {
        $whereClauses[] = "t.id IN (SELECT team_id FROM players WHERE LOWER(name) = ?)";
        $params[] = strtolower($playerName);
    }

    if (!empty($whereClauses)) {
        $whereSql = implode(' OR ', $whereClauses);
        $stmt = $pdo->prepare("
            SELECT t.*, 
                   (SELECT COUNT(*) FROM players p WHERE p.team_id = t.id) as player_count 
            FROM teams t 
            WHERE {$whereSql} 
            ORDER BY t.id DESC
        ");
        $stmt->execute($params);
        $myTeams = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } else {
        // Fallback: If not logged in and no specific owner given, only return user-created teams (owner_id IS NOT NULL) or recently created user teams
        $stmt = $pdo->query("
            SELECT t.*, 
                   (SELECT COUNT(*) FROM players p WHERE p.team_id = t.id) as player_count 
            FROM teams t 
            WHERE t.owner_id IS NOT NULL OR t.tournament_id IS NULL OR t.id NOT IN (SELECT id FROM teams WHERE name IN ('Team A','Team B','Team C','Team D','A','B','C','D'))
            ORDER BY t.id DESC LIMIT 10
        ");
        $myTeams = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    echo json_encode(['success' => true, 'teams' => $myTeams]);
    exit;
}

// ── 9. DUAL PLAYER SEARCH (Phone Number or Name) ───────────────────────────
if ($action === 'search_players') {
    $q = trim($_GET['q'] ?? '');
    if (empty($q) || strlen($q) < 2) {
        echo json_encode(['success' => true, 'players' => []]);
        exit;
    }

    $rawQ = $q;
    // Extract pure digits for mobile number search
    $digitsOnly = preg_replace('/\D+/', '', $q);
    $last10 = (strlen($digitsOnly) >= 10) ? substr($digitsOnly, -10) : $digitsOnly;

    $likeName = '%' . strtolower($rawQ) . '%';
    $likeMobile = !empty($last10) ? '%' . $last10 . '%' : '%' . $rawQ . '%';

    $playersList = [];
    $seenMobiles = [];
    $seenNames = [];

    // 1. First, search registered App Users (app_users table)
    try {
        $uStmt = $pdo->prepare("
            SELECT id, name, mobile, role, batting_style, bowling_style, jersey_number, profile_pic, city
            FROM app_users
            WHERE LOWER(name) LIKE ? OR mobile LIKE ?
            ORDER BY id DESC LIMIT 20
        ");
        $uStmt->execute([$likeName, $likeMobile]);
        $appUsers = $uStmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($appUsers as $u) {
            $mob = trim($u['mobile'] ?? '');
            $nm = trim($u['name'] ?? '');
            if (!empty($mob)) $seenMobiles[$mob] = true;
            if (!empty($nm)) $seenNames[strtolower($nm)] = true;

            $playersList[] = [
                'id'            => (int)$u['id'],
                'name'          => !empty($u['name']) ? $u['name'] : 'Player (' . $mob . ')',
                'mobile'        => $mob,
                'role'          => !empty($u['role']) ? $u['role'] : 'All-Rounder',
                'batting_style' => !empty($u['batting_style']) ? $u['batting_style'] : 'Right Hand Bat',
                'bowling_style' => !empty($u['bowling_style']) ? $u['bowling_style'] : 'Right Arm Medium',
                'jersey_number' => $u['jersey_number'] ?? '',
                'profile_pic'   => $u['profile_pic'] ?? null,
                'city'          => $u['city'] ?? '',
                'team_name'     => 'Registered User ⭐',
                'source'        => 'app_user',
            ];
        }
    } catch (\Throwable $e) {
        // Table might not exist or query error, continue
    }

    // 2. Next, search Tournament Players (players table)
    try {
        $pStmt = $pdo->prepare("
            SELECT p.id, p.name, p.mobile, p.role, p.batting_style, p.bowling_style, p.jersey_number, p.profile_pic,
                   t.id as team_id, t.name as team_name
            FROM players p
            LEFT JOIN teams t ON t.id = p.team_id
            WHERE LOWER(p.name) LIKE ? OR p.mobile LIKE ?
            ORDER BY p.id DESC LIMIT 20
        ");
        $pStmt->execute([$likeName, $likeMobile]);
        $tournamentPlayers = $pStmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($tournamentPlayers as $p) {
            $mob = trim($p['mobile'] ?? '');
            $nm = trim($p['name'] ?? '');

            // If already added from app_users, skip duplicate
            if (!empty($mob) && isset($seenMobiles[$mob])) continue;
            if (empty($mob) && !empty($nm) && isset($seenNames[strtolower($nm)])) continue;

            if (!empty($mob)) $seenMobiles[$mob] = true;
            if (!empty($nm)) $seenNames[strtolower($nm)] = true;

            $playersList[] = [
                'id'            => (int)$p['id'],
                'name'          => $p['name'],
                'mobile'        => $mob,
                'role'          => !empty($p['role']) ? $p['role'] : 'BAT',
                'batting_style' => !empty($p['batting_style']) ? $p['batting_style'] : 'Right Hand Bat',
                'bowling_style' => !empty($p['bowling_style']) ? $p['bowling_style'] : 'Right Arm Medium',
                'jersey_number' => $p['jersey_number'] ?? '',
                'profile_pic'   => $p['profile_pic'] ?? null,
                'team_name'     => $p['team_name'] ?? '',
                'source'        => 'tournament_player',
            ];
        }
    } catch (\Throwable $e) {
        // Continue
    }

    echo json_encode(['success' => true, 'query' => $q, 'players' => $playersList]);
    exit;
}


// ── 10. SET CAPTAIN ─────────────────────────────────────────────────────────
if ($action === 'set_captain') {
    $input    = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $teamId   = (int)($input['team_id'] ?? 0);
    $playerId = (int)($input['player_id'] ?? 0);

    if ($teamId <= 0 || $playerId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'team_id and player_id are required']);
        exit;
    }

    $pdo->prepare("UPDATE players SET is_captain = 0 WHERE team_id = ?")->execute([$teamId]);
    $stmt = $pdo->prepare("UPDATE players SET is_captain = 1 WHERE id = ? AND team_id = ?");
    $stmt->execute([$playerId, $teamId]);

    echo json_encode(['success' => true, 'message' => 'Captain updated successfully! 👑']);
    exit;
}

// ── 11. REMOVE PLAYER FROM SQUAD ────────────────────────────────────────────
if ($action === 'remove_player') {
    $input    = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $teamId   = (int)($input['team_id'] ?? 0);
    $playerId = (int)($input['player_id'] ?? 0);

    if ($teamId <= 0 || $playerId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'team_id and player_id are required']);
        exit;
    }

    $stmt = $pdo->prepare("DELETE FROM players WHERE id = ? AND team_id = ?");
    $stmt->execute([$playerId, $teamId]);

    echo json_encode(['success' => true, 'message' => 'Player removed from squad']);
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);
