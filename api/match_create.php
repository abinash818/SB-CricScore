<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login($pdo);
header('Content-Type: application/json');

$tid = (int)($_POST['tournament_id'] ?? 0);
$team_a = (int)($_POST['team_a_id'] ?? 0);
$team_b = (int)($_POST['team_b_id'] ?? 0);
$bat_first = (int)($_POST['batting_first_team_id'] ?? 0);
$overs = (int)($_POST['overs_limit'] ?? 20);
$is_final = (int)($_POST['is_final'] ?? 0);
$match_date = trim($_POST['match_date'] ?? '');
$match_time = trim($_POST['match_time'] ?? '');
$stage = trim($_POST['stage'] ?? ($is_final ? 'Final' : 'League'));

if ($tid<=0 || $team_a<=0 || $team_b<=0) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid input']);
    exit;
}

if ($team_a === $team_b) {
    http_response_code(400);
    echo json_encode(['error' => 'Team A and Team B cannot be the same!']);
    exit;
}

try {
    $pdo->beginTransaction();
    
    $status = ($bat_first > 0) ? 'live' : 'scheduled';
    $toss_winner = ($bat_first > 0) ? $bat_first : null;
    $toss_dec = ($bat_first > 0) ? 'bat' : null;

    $stmt = $pdo->prepare("
        INSERT INTO matches (tournament_id, team_a_id, team_b_id, toss_winner_team_id, toss_decision, overs_limit, is_final, match_date, match_time, stage, status) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $tid, $team_a, $team_b, $toss_winner, $toss_dec, $overs, $is_final,
        ($match_date ?: null), ($match_time ?: null), ($stage ?: 'League'), $status
    ]);
    $match_id = $pdo->lastInsertId();

    if ($bat_first > 0) {
        $bowling = ($bat_first == $team_a ? $team_b : $team_a);
        // Create Innings 1
        $i1 = $pdo->prepare("INSERT INTO innings (match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES (?, 1, ?, ?, 0)");
        $i1->execute([$match_id, $bat_first, $bowling]);

        // Create Innings 2
        $i2 = $pdo->prepare("INSERT INTO innings (match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES (?, 2, ?, ?, 0)");
        $i2->execute([$match_id, $bowling, $bat_first]);
    }

    $pdo->commit();
    echo json_encode(['ok' => true, 'match_id' => $match_id]);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>