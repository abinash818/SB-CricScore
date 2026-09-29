<?php
// api/match_join_qr.php
// Connects Opponent Team (Team B) to a match fixture via QR Code scan or invite link
// POST { "match_code": "SB8921", "team_id": 5, "player_ids": [12,13,...] }

header('Content-Type: application/json; charset=utf-8');
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
    echo json_encode(['success' => false, 'message' => 'Opponent team_id is required']);
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
    $match = $stmt->fetch();

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
        $delXI = $pdo->prepare("DELETE FROM match_playing_xi WHERE match_id = ? AND team_id = ?");
        $delXI->execute([$actualMatchId, $team_id]);

        $insXI = $pdo->prepare("INSERT INTO match_playing_xi (match_id, team_id, player_id, batting_order) VALUES (?, ?, ?, ?)");
        $order = 1;
        foreach ($player_ids as $pid) {
            $insXI->execute([$actualMatchId, $team_id, (int)$pid, $order++]);
        }
    }

    $pdo->commit();

    // Fetch team names
    $taStmt = $pdo->prepare("SELECT name FROM teams WHERE id = ?");
    $taStmt->execute([$match['team_a_id']]);
    $teamAName = $taStmt->fetchColumn() ?: 'Team A';

    $tbStmt = $pdo->prepare("SELECT name FROM teams WHERE id = ?");
    $tbStmt->execute([$team_id]);
    $teamBName = $tbStmt->fetchColumn() ?: 'Opponent';

    echo json_encode([
        'success'      => true,
        'message'      => "Match confirmed! {$teamBName} joined vs {$teamAName}",
        'match_id'     => $actualMatchId,
        'match_code'   => $match['match_code'],
        'team_a_name'  => $teamAName,
        'team_b_name'  => $teamBName,
        'status'       => $match['status']
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error joining match: ' . $e->getMessage()]);
}
