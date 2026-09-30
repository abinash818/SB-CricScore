<?php
// api/match_join_qr.php
// Connects Opponent Team (Team B) to a match fixture via QR Code scan or invite link
// GET  /api/match_join_qr.php?action=get_invite&match_code=SB8921
// POST { "match_code": "SB8921", "team_id": 5, "player_ids": [12,13,...] }

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { 
    http_response_code(200); 
    exit; 
}

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$action = $_GET['action'] ?? ($_POST['action'] ?? 'join');

// ── 1. GET MATCH INVITE DETAILS (Preview before accepting) ──────────────────
if ($action === 'get_invite' || $_SERVER['REQUEST_METHOD'] === 'GET') {
    $match_code = strtoupper(trim($_GET['match_code'] ?? ''));
    $match_id   = (int)($_GET['match_id'] ?? 0);

    if (empty($match_code) && $match_id <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'match_code or match_id is required']);
        exit;
    }

    try {
        if (!empty($match_code)) {
            $stmt = $pdo->prepare("SELECT * FROM matches WHERE UPPER(match_code) = ?");
            $stmt->execute([$match_code]);
        } else {
            $stmt = $pdo->prepare("SELECT * FROM matches WHERE id = ?");
            $stmt->execute([$match_id]);
        }
        $match = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$match) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Match not found or invalid QR code / PIN']);
            exit;
        }

        $teamAId = (int)$match['team_a_id'];
        $teamBId = (int)($match['team_b_id'] ?? 0);

        $taStmt = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
        $taStmt->execute([$teamAId]);
        $teamA = $taStmt->fetch(PDO::FETCH_ASSOC);

        $teamB = null;
        if ($teamBId > 0) {
            $tbStmt = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
            $tbStmt->execute([$teamBId]);
            $teamB = $tbStmt->fetch(PDO::FETCH_ASSOC);
        }

        // Check Playing XI count for Team A
        $xiStmt = $pdo->prepare("SELECT COUNT(*) FROM match_playing_xi WHERE match_id = ? AND team_id = ?");
        $xiStmt->execute([(int)$match['id'], $teamAId]);
        $teamAPlayingXiCount = (int)$xiStmt->fetchColumn();

        $ballTypeLabels = [
            'tennis_light' => '🎾 Tennis (Light)',
            'tennis_heavy' => '🎾 Tennis (Heavy)',
            'leather'      => '🏏 Leather Ball',
            'rubber'       => '⚪ Rubber Ball',
        ];

        echo json_encode([
            'success'               => true,
            'match_id'              => (int)$match['id'],
            'match_code'            => $match['match_code'],
            'tournament_id'         => (int)($match['tournament_id'] ?? 0),
            'host_team_id'          => $teamAId,
            'host_team_name'        => $teamA['name'] ?? 'Host Team',
            'host_team_short'       => $teamA['short_name'] ?? 'HOST',
            'host_team_icon'        => $teamA['icon'] ?? 'shield',
            'host_playing_xi_count' => $teamAPlayingXiCount,
            'opponent_team_id'      => $teamBId,
            'opponent_team_name'    => $teamB ? $teamB['name'] : null,
            'venue_name'            => $match['venue_name'] ?? 'Cricket Ground',
            'overs_limit'           => (int)($match['overs_limit'] ?? 20),
            'wickets_limit'         => (int)($match['wickets_limit'] ?? 10),
            'ball_type'             => $match['ball_type'] ?? 'tennis_light',
            'ball_type_label'       => $ballTypeLabels[$match['ball_type'] ?? 'tennis_light'] ?? '🏏 Tennis Ball',
            'match_date'            => $match['match_date'] ?? null,
            'match_time'            => $match['match_time'] ?? null,
            'status'                => $match['status'] ?? 'scheduled',
            'invite_status'         => $match['invite_status'] ?? 'pending',
            'is_scheduled'          => (!empty($match['match_date']) || !empty($match['match_time'])),
        ]);
        exit;
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
        exit;
    }
}

// ── 2. CONFIRM & JOIN MATCH VIA QR / PIN ────────────────────────────────────
$input      = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$match_code = strtoupper(trim($input['match_code'] ?? ''));
$match_id   = (int)($input['match_id'] ?? 0);
$team_id    = (int)($input['team_id'] ?? 0);
$player_ids = $input['player_ids'] ?? [];

if (empty($match_code) && $match_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_code or match_id is required']);
    exit;
}

if ($team_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Please select your team to join the match']);
    exit;
}

try {
    // 1. Locate Match
    if (!empty($match_code)) {
        $stmt = $pdo->prepare("SELECT * FROM matches WHERE UPPER(match_code) = ?");
        $stmt->execute([$match_code]);
    } else {
        $stmt = $pdo->prepare("SELECT * FROM matches WHERE id = ?");
        $stmt->execute([$match_id]);
    }
    $match = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$match) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Match not found or invalid match code']);
        exit;
    }

    $actualMatchId = (int)$match['id'];

    if ((int)$match['team_a_id'] === $team_id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'You cannot join as opponent against your own team']);
        exit;
    }

    $pdo->beginTransaction();

    // 2. Attach Team B to Match
    $upStmt = $pdo->prepare("UPDATE matches SET team_b_id = ?, invite_status = 'accepted' WHERE id = ?");
    $upStmt->execute([$team_id, $actualMatchId]);

    // 3. Save Playing XI for Team B if provided
    if (!empty($player_ids) && is_array($player_ids)) {
        try {
            $pdo->exec("
                CREATE TABLE IF NOT EXISTS match_playing_xi (
                    id            INT AUTO_INCREMENT PRIMARY KEY,
                    match_id      INT NOT NULL,
                    team_id       INT NOT NULL,
                    player_id     INT NOT NULL,
                    is_substitute TINYINT(1) DEFAULT 0,
                    is_captain    TINYINT(1) DEFAULT 0,
                    is_keeper     TINYINT(1) DEFAULT 0,
                    batting_order INT DEFAULT NULL,
                    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_mpxi_match (match_id),
                    INDEX idx_mpxi_team (team_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            ");
            $delXI = $pdo->prepare("DELETE FROM match_playing_xi WHERE match_id = ? AND team_id = ?");
            $delXI->execute([$actualMatchId, $team_id]);

            $insXI = $pdo->prepare("INSERT INTO match_playing_xi (match_id, team_id, player_id, batting_order) VALUES (?, ?, ?, ?)");
            $order = 1;
            foreach ($player_ids as $pid) {
                $insXI->execute([$actualMatchId, $team_id, (int)$pid, $order++]);
            }
        } catch (Throwable $e) {}
    }

    $pdo->commit();

    // Fetch team names
    $taStmt = $pdo->prepare("SELECT name FROM teams WHERE id = ?");
    $taStmt->execute([$match['team_a_id']]);
    $teamAName = $taStmt->fetchColumn() ?: 'Host Team';

    $tbStmt = $pdo->prepare("SELECT name FROM teams WHERE id = ?");
    $tbStmt->execute([$team_id]);
    $teamBName = $tbStmt->fetchColumn() ?: 'Opponent';

    $isScheduled = (!empty($match['match_date']) || !empty($match['match_time']));

    echo json_encode([
        'success'      => true,
        'message'      => "Match confirmed! {$teamBName} joined vs {$teamAName}",
        'match_id'     => $actualMatchId,
        'match_code'   => $match['match_code'],
        'team_a_id'    => (int)$match['team_a_id'],
        'team_a_name'  => $teamAName,
        'team_b_id'    => $team_id,
        'team_b_name'  => $teamBName,
        'overs_limit'  => (int)($match['overs_limit'] ?? 20),
        'venue_name'   => $match['venue_name'] ?? 'Cricket Ground',
        'is_scheduled' => $isScheduled,
        'status'       => $match['status']
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error joining match: ' . $e->getMessage()]);
}
