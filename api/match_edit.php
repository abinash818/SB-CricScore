<?php
// api/match_edit.php - Edit Match Details (Teams, Date, Time, Stage, Overs)
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login($pdo);
header('Content-Type: application/json');

$match_id = (int)($_POST['match_id'] ?? 0);
$team_a = (int)($_POST['team_a_id'] ?? 0);
$team_b = (int)($_POST['team_b_id'] ?? 0);
$overs = (int)($_POST['overs_limit'] ?? 20);
$is_final = (int)($_POST['is_final'] ?? 0);
$match_date = trim($_POST['match_date'] ?? '');
$match_time = trim($_POST['match_time'] ?? '');
$stage = trim($_POST['stage'] ?? 'League');

if ($match_id <= 0 || $team_a <= 0 || $team_b <= 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid match ID or team IDs']);
    exit;
}

if ($team_a === $team_b) {
    http_response_code(400);
    echo json_encode(['error' => 'Team A and Team B cannot be the same!']);
    exit;
}

try {
    $stmt = $pdo->prepare("SELECT * FROM matches WHERE id=?");
    $stmt->execute([$match_id]);
    $match = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$match) {
        http_response_code(404);
        echo json_encode(['error' => 'Match not found']);
        exit;
    }

    $upd = $pdo->prepare("
        UPDATE matches 
        SET team_a_id = ?, team_b_id = ?, overs_limit = ?, is_final = ?, match_date = ?, match_time = ?, stage = ?
        WHERE id = ?
    ");
    $upd->execute([
        $team_a,
        $team_b,
        $overs,
        $is_final,
        ($match_date ?: null),
        ($match_time ?: null),
        ($stage ?: 'League'),
        $match_id
    ]);

    // If match is still scheduled and innings exist, update their teams
    if ($match['status'] === 'scheduled') {
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=? WHERE match_id=? AND innings_no=1")->execute([$team_a, $team_b, $match_id]);
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=? WHERE match_id=? AND innings_no=2")->execute([$team_b, $team_a, $match_id]);
    }

    echo json_encode(['ok' => true, 'message' => 'Match details updated successfully!']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>
