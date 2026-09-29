<?php
// api/match_playing_xi.php
// Manages Match Lineup: 11 Playing XI + up to 3 Substitutes (Max 14 players total)
// POST { "match_id": 1, "team_id": 2, "playing_xi_ids": [1,2,3,4,5,6,7,8,9,10,11], "substitute_ids": [12,13,14], "captain_id": 1, "wicketkeeper_id": 2 }
// GET  /api/match_playing_xi.php?match_id=1

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$method = $_SERVER['REQUEST_METHOD'];

// ── 1. GET PLAYING XI & SUBSTITUTES FOR A MATCH ────────────────────────────
if ($method === 'GET') {
    $matchId = (int)($_GET['match_id'] ?? 0);
    if ($matchId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'match_id is required']);
        exit;
    }

    $mStmt = $pdo->prepare("SELECT id, team_a_id, team_b_id FROM matches WHERE id = ?");
    $mStmt->execute([$matchId]);
    $match = $mStmt->fetch();

    if (!$match) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Match not found']);
        exit;
    }

    // Fetch Playing Lineup for both teams
    $xiStmt = $pdo->prepare("
        SELECT xi.*, p.name, p.role, p.jersey_number, p.profile_pic, p.batting_style, p.bowling_style
        FROM match_playing_xi xi
        JOIN players p ON p.id = xi.player_id
        WHERE xi.match_id = ?
        ORDER BY xi.is_substitute ASC, xi.batting_order ASC, xi.id ASC
    ");
    $xiStmt->execute([$matchId]);
    $allPlayers = $xiStmt->fetchAll(PDO::FETCH_ASSOC);

    $teamA_XI   = [];
    $teamA_Subs = [];
    $teamB_XI   = [];
    $teamB_Subs = [];

    foreach ($allPlayers as $player) {
        $isTeamA = ((int)$player['team_id'] === (int)$match['team_a_id']);
        $isSub   = ((int)($player['is_substitute'] ?? 0) === 1);

        if ($isTeamA) {
            if ($isSub) {
                $teamA_Subs[] = $player;
            } else {
                $teamA_XI[] = $player;
            }
        } else {
            if ($isSub) {
                $teamB_Subs[] = $player;
            } else {
                $teamB_XI[] = $player;
            }
        }
    }

    echo json_encode([
        'success'            => true,
        'match_id'           => $matchId,
        'team_a_playing_xi'  => $teamA_XI,
        'team_a_substitutes' => $teamA_Subs,
        'team_a_xi_count'    => count($teamA_XI),
        'team_a_sub_count'   => count($teamA_Subs),
        'team_b_playing_xi'  => $teamB_XI,
        'team_b_substitutes' => $teamB_Subs,
        'team_b_xi_count'    => count($teamB_XI),
        'team_b_sub_count'   => count($teamB_Subs)
    ]);
    exit;
}

// ── 2. SAVE PLAYING XI & SUBSTITUTES (POST) ────────────────────────────────
if ($method === 'POST') {
    $input        = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $matchId      = (int)($input['match_id'] ?? 0);
    $teamId       = (int)($input['team_id'] ?? 0);
    $captainId    = (int)($input['captain_id'] ?? 0);
    $wkId         = (int)($input['wicketkeeper_id'] ?? 0);

    // Support both structured input and flat player_ids
    $playingXiIds = $input['playing_xi_ids'] ?? [];
    $substituteIds = $input['substitute_ids'] ?? [];

    if (empty($playingXiIds) && !empty($input['player_ids'])) {
        $flatList = (array)$input['player_ids'];
        $playingXiIds = array_slice($flatList, 0, 11);
        $substituteIds = array_slice($flatList, 11, 3); // Max 3 substitutes
    }

    if ($matchId <= 0 || $teamId <= 0 || empty($playingXiIds)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'match_id, team_id, and playing_xi_ids (up to 11) are required']);
        exit;
    }

    if (count($playingXiIds) > 11) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Primary Playing XI cannot exceed 11 players. Additional players must be added as Substitutes.']);
        exit;
    }

    if (count($substituteIds) > 3) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Substitutes cannot exceed 3 players (11 Playing XI + Max 3 Substitutes).']);
        exit;
    }

    try {
        $pdo->beginTransaction();

        // Remove previous Lineup for this team in this match
        $delStmt = $pdo->prepare("DELETE FROM match_playing_xi WHERE match_id = ? AND team_id = ?");
        $delStmt->execute([$matchId, $teamId]);

        // Insert new Lineup (Playing 11 + Substitutes)
        $insStmt = $pdo->prepare("
            INSERT INTO match_playing_xi (match_id, team_id, player_id, is_captain, is_wicketkeeper, is_substitute, batting_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");

        // 1. Insert Playing XI (is_substitute = 0)
        $order = 1;
        foreach ($playingXiIds as $pid) {
            $pid = (int)$pid;
            $isCapt = ($pid === $captainId) ? 1 : 0;
            $isWk   = ($pid === $wkId) ? 1 : 0;
            $insStmt->execute([$matchId, $teamId, $pid, $isCapt, $isWk, 0, $order++]);
        }

        // 2. Insert Substitutes (is_substitute = 1)
        $subOrder = 1;
        foreach ($substituteIds as $subPid) {
            $subPid = (int)$subPid;
            if (in_array($subPid, $playingXiIds)) continue; // Avoid duplicate
            $insStmt->execute([$matchId, $teamId, $subPid, 0, 0, 1, 100 + $subOrder++]);
        }

        $pdo->commit();

        echo json_encode([
            'success'          => true,
            'message'          => 'Playing XI and Substitutes saved successfully!',
            'match_id'         => $matchId,
            'team_id'          => $teamId,
            'playing_xi_count' => count($playingXiIds),
            'substitute_count' => count($substituteIds),
            'total_lineup'     => count($playingXiIds) + count($substituteIds)
        ]);

    } catch (Exception $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to save Lineup: ' . $e->getMessage()]);
    }
    exit;
}
