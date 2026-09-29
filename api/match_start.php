<?php
// api/match_start.php
// Starts match, records toss result and initializes innings 1 & 2
// POST (JSON or Form Data)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;

$match_id      = (int)($input['match_id'] ?? 0);
$bat_first     = (int)($input['batting_first_team_id'] ?? 0);
$toss_winner   = (int)($input['toss_winner_team_id'] ?? 0);
$toss_decision = trim($input['toss_decision'] ?? 'bat');

if ($match_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_id is required']);
    exit;
}

$stmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
$stmt->execute([$match_id]);
$m = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$m) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Match not found']);
    exit;
}

$teamA = (int)$m['team_a_id'];
$teamB = (int)$m['team_b_id'];

if ($bat_first <= 0) {
    if ($toss_winner <= 0) $toss_winner = $teamA;
    if ($toss_decision === 'bowl') {
        $bat_first = ($toss_winner === $teamA) ? $teamB : $teamA;
    } else {
        $bat_first = $toss_winner;
    }
}

if ($bat_first !== $teamA && $bat_first !== $teamB) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Batting team must be Team A or Team B']);
    exit;
}

$bowling = ($bat_first === $teamA) ? $teamB : $teamA;
if ($toss_winner <= 0) $toss_winner = $bat_first;

try {
    $pdo->beginTransaction();

    // Create Innings 1 if not exists
    $chk1 = $pdo->prepare("SELECT id FROM innings WHERE match_id=? AND innings_no=1");
    $chk1->execute([$match_id]);
    $i1 = $chk1->fetch(PDO::FETCH_ASSOC);
    if (!$i1) {
        $ins1 = $pdo->prepare("INSERT INTO innings(match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES(?, 1, ?, ?, 0)");
        $ins1->execute([$match_id, $bat_first, $bowling]);
        $inn1_id = (int)$pdo->lastInsertId();
    } else {
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=? WHERE id=?")->execute([$bat_first, $bowling, $i1['id']]);
        $inn1_id = (int)$i1['id'];
    }

    // Create Innings 2 if not exists
    $chk2 = $pdo->prepare("SELECT id FROM innings WHERE match_id=? AND innings_no=2");
    $chk2->execute([$match_id]);
    $i2 = $chk2->fetch(PDO::FETCH_ASSOC);
    if (!$i2) {
        $ins2 = $pdo->prepare("INSERT INTO innings(match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES(?, 2, ?, ?, 0)");
        $ins2->execute([$match_id, $bowling, $bat_first]);
    } else {
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=? WHERE id=?")->execute([$bowling, $bat_first, $i2['id']]);
    }

    // Update Match status to live
    $upd = $pdo->prepare("UPDATE matches SET status='live', toss_winner_team_id=?, toss_decision=? WHERE id=?");
    $upd->execute([$toss_winner, $toss_decision, $match_id]);

    $pdo->commit();

    echo json_encode([
        'success'      => true,
        'ok'           => true,
        'match_id'     => $match_id,
        'innings_id'   => $inn1_id,
        'batting_team' => $bat_first,
        'bowling_team' => $bowling,
        'message'      => 'Match started successfully'
    ]);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
