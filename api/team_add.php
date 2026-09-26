<?php
// api/team_add.php - Add New Team or Clone Existing Team with Squad
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login($pdo);
header('Content-Type: application/json');

$tid = (int)($_POST['tournament_id'] ?? 0);
$action = $_POST['action'] ?? 'add';
$cloneSourceTeamId = (int)($_POST['clone_source_team_id'] ?? 0);

if ($tid <= 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Tournament ID required']);
    exit;
}

// 1. CLONE EXISTING TEAM WITH SQUAD
if ($action === 'clone' && $cloneSourceTeamId > 0) {
    try {
        $st = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
        $st->execute([$cloneSourceTeamId]);
        $srcTeam = $st->fetch(PDO::FETCH_ASSOC);
        if (!$srcTeam) {
            http_response_code(404);
            echo json_encode(['error' => 'Source team not found']);
            exit;
        }

        // Check if team with same name already exists in target tournament
        $chk = $pdo->prepare("SELECT id FROM teams WHERE tournament_id = ? AND LOWER(TRIM(name)) = ?");
        $chk->execute([$tid, strtolower(trim($srcTeam['name']))]);
        if ($chk->fetch()) {
            http_response_code(400);
            echo json_encode(['error' => "Team '{$srcTeam['name']}' already exists in this tournament!"]);
            exit;
        }

        // Insert new team into target tournament
        $insTeam = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
        $insTeam->execute([$tid, $srcTeam['name'], $srcTeam['short_name'], $srcTeam['icon']]);
        $newTeamId = (int)$pdo->lastInsertId();

        // Copy all players from source team
        $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ?");
        $pStmt->execute([$cloneSourceTeamId]);
        $srcPlayers = $pStmt->fetchAll(PDO::FETCH_ASSOC);

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
                $p['bowling_style'] ?? 'Right Arm Medium'
            ]);
            $copiedCount++;
        }

        echo json_encode([
            'ok' => true,
            'message' => "Team '{$srcTeam['name']}' and {$copiedCount} player(s) cloned successfully into tournament!",
            'team_id' => $newTeamId,
            'players_copied' => $copiedCount
        ]);
        exit;
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
        exit;
    }
}

// 2. STANDARD TEAM ADDITION
$name = trim($_POST['names'] ?? '');
$short = trim($_POST['short_name'] ?? '');
$icon = trim($_POST['icon'] ?? 'shield');

if (empty($name)) {
    http_response_code(400);
    echo json_encode(['error' => 'Team name is required']);
    exit;
}

if (empty($short)) {
    $short = strtoupper(substr(preg_replace('/[^A-Za-z0-9]/', '', $name), 0, 3));
    if (empty($short)) $short = 'TEM';
}

try {
    $stmt = $pdo->prepare("INSERT INTO teams (name, short_name, icon, tournament_id) VALUES (?, ?, ?, ?)");
    $stmt->execute([$name, $short, $icon, $tid]);
    
    $all = $pdo->prepare("SELECT * FROM teams WHERE tournament_id=? ORDER BY name");
    $all->execute([$tid]);
    
    echo json_encode(['ok' => true, 'teams' => $all->fetchAll(PDO::FETCH_ASSOC)]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}