<?php
// api/ball_undo.php
// Undoes the last ball recorded in an innings
// POST (JSON or Form Data)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;

$innings_id = (int)($input['innings_id'] ?? 0);
if ($innings_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'innings_id is required']);
    exit;
}

// 1. Find last ball
$stmt = $pdo->prepare('SELECT id FROM ball_events WHERE innings_id=? ORDER BY seq DESC LIMIT 1');
$stmt->execute([$innings_id]);
$id = $stmt->fetchColumn();

if (!$id) {
    echo json_encode(['success' => true, 'ok' => true, 'message' => 'Nothing to undo']);
    exit;
}

// 2. Delete last ball
$del = $pdo->prepare('DELETE FROM ball_events WHERE id=?');
$del->execute([$id]);

// 3. Reset Completion (Unlock Innings & Match)
$pdo->prepare("UPDATE innings SET completed=0 WHERE id=?")->execute([$innings_id]);
$pdo->prepare("
    UPDATE matches 
    SET status='live', winner_team_id=NULL, result_type=NULL 
    WHERE id=(SELECT match_id FROM innings WHERE id=?)
")->execute([$innings_id]);

// 4. Update Target (If 1st Innings modified)
$meta = $pdo->prepare("SELECT innings_no, match_id FROM innings WHERE id=?");
$meta->execute([$innings_id]);
$inn = $meta->fetch(PDO::FETCH_ASSOC);

if ($inn && (int)$inn['innings_no'] === 1) {
    $stmtT = $pdo->prepare("SELECT SUM(runs_bat+extras_runs) as runs FROM ball_events WHERE innings_id=?");
    $stmtT->execute([$innings_id]);
    $newTotal = (int)($stmtT->fetchColumn() ?: 0);
    $newTarget = $newTotal + 1;
    $pdo->prepare("UPDATE innings SET target=? WHERE match_id=? AND innings_no=2")->execute([$newTarget, $inn['match_id']]);
}

echo json_encode(['success' => true, 'ok' => true, 'message' => 'Last ball undone successfully']);