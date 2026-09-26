<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login($pdo);
header('Content-Type: application/json');

$match_id = (int)($_POST['match_id'] ?? 0);
$bat_first = (int)($_POST['batting_first_team_id'] ?? 0);
$toss_winner = (int)($_POST['toss_winner_team_id'] ?? 0);
$toss_decision = trim($_POST['toss_decision'] ?? 'bat');

if ($match_id <= 0) {
    http_response_code(400);
    echo json_encode(['error' => 'match_id required']);
    exit;
}

$stmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
$stmt->execute([$match_id]);
$m = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$m) {
    http_response_code(404);
    echo json_encode(['error' => 'Match not found']);
    exit;
}

$teamA = (int)$m['team_a_id'];
$teamB = (int)$m['team_b_id'];

// If bat_first is not passed directly, compute from toss winner & decision
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
    echo json_encode(['error' => 'Batting team must be Team A or Team B']);
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
    } else {
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=? WHERE id=?")->execute([$bat_first, $bowling, $i1['id']]);
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

    $pdo->prepare("UPDATE matches SET status='live', toss_winner_team_id=?, toss_decision=? WHERE id=?")->execute([$toss_winner, $toss_decision, $match_id]);

    $pdo->commit();
    echo json_encode(['ok' => true]);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>
