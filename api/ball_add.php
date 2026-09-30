<?php
// api/ball_add.php
// Records a ball event (runs, extras, wickets)
// POST (JSON or Form Data)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;

function calc_totals($pdo, $inn_id) {
    $stmt = $pdo->prepare("SELECT COUNT(CASE WHEN is_legal=1 THEN 1 END) as legal, SUM(runs_bat+extras_runs) as runs, SUM(CASE WHEN is_wicket=1 THEN 1 END) as wkts FROM ball_events WHERE innings_id=?");
    $stmt->execute([$inn_id]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

$innings_id  = (int)($input['innings_id'] ?? 0);
$runs_bat    = (int)($input['runs_bat'] ?? 0);
$extras_type = trim($input['extras_type'] ?? '');
$extras_runs = (int)($input['extras_runs'] ?? 0);
$is_wicket   = (int)($input['is_wicket'] ?? 0);
$wicket_type = trim($input['wicket_type'] ?? '');

if ($is_wicket && (stripos($wicket_type, 'run') !== false && stripos($wicket_type, 'out') !== false)) {
    $wicket_type = 'run out';
}

$striker_id = (int)($input['striker_id'] ?? 0);
$non_striker_id = (int)($input['non_striker_id'] ?? 0);
$bowler_id = (int)($input['bowler_id'] ?? 0);
$wicket_player_out_id = (int)($input['wicket_player_out_id'] ?? 0); 

if ($innings_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'innings_id is required']);
    exit;
}

// 1. Fetch Meta
$meta = $pdo->prepare("SELECT i.*, m.status AS match_status, m.overs_limit AS match_overs, m.wickets_limit AS match_wickets FROM innings i JOIN matches m ON m.id=i.match_id WHERE i.id=?");
$meta->execute([$innings_id]);
$inn = $meta->fetch(PDO::FETCH_ASSOC);

if (!$inn) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Innings not found']);
    exit;
}

// 2. Reset Status if needed
if ((int)$inn['completed'] === 1 || $inn['match_status'] === 'completed') {
    $pdo->prepare("UPDATE innings SET completed=0 WHERE id=?")->execute([$innings_id]);
    $pdo->prepare("UPDATE matches SET status='live', winner_team_id=NULL, result_type=NULL WHERE id=?")->execute([$inn['match_id']]);
}

// Check if current ball is a Free Hit (either passed explicitly or if last ball was a No Ball)
$lastBallStmt = $pdo->prepare("SELECT extras_type, is_free_hit FROM ball_events WHERE innings_id=? ORDER BY seq DESC LIMIT 1");
$lastBallStmt->execute([$innings_id]);
$lastBall = $lastBallStmt->fetch(PDO::FETCH_ASSOC);

$is_free_hit = (int)($input['is_free_hit'] ?? 0);
if (!$is_free_hit && $lastBall && $lastBall['extras_type'] === 'nb') {
    $is_free_hit = 1;
}

// On Free Hit, only Run Out is a valid wicket
if ($is_free_hit && $is_wicket && $wicket_type !== 'run out') {
    // Cannot be out bowled/caught/lbw on Free Hit
    $is_wicket = 0;
    $wicket_type = '';
    $wicket_player_out_id = 0;
}

$is_legal = ($extras_type === 'wd' || $extras_type === 'nb') ? 0 : 1;
$stmt = $pdo->prepare('SELECT COALESCE(MAX(seq),0)+1 FROM ball_events WHERE innings_id=?');
$stmt->execute([$innings_id]);
$next_seq = (int)$stmt->fetchColumn();

// 3. Insert Ball Event with is_free_hit
$stmt = $pdo->prepare("INSERT INTO ball_events(innings_id, seq, striker_id, non_striker_id, bowler_id, runs_bat, extras_type, extras_runs, is_wicket, wicket_type, wicket_player_out_id, is_legal, is_free_hit) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)");
$stmt->execute([$innings_id, $next_seq, ($striker_id?:null), ($non_striker_id?:null), ($bowler_id?:null), $runs_bat, ($extras_type!==''?$extras_type:null), $extras_runs, $is_wicket?1:0, ($wicket_type!==''?$wicket_type:null), ($wicket_player_out_id?:null), $is_legal, $is_free_hit]);

// 4. Update Target (Logic)
if ((int)$inn['innings_no'] === 1) {
    $t = calc_totals($pdo, $innings_id);
    $newTarget = $t['runs'] + 1;
    $pdo->prepare("UPDATE innings SET target=? WHERE match_id=? AND innings_no=2")->execute([$newTarget, $inn['match_id']]);
}

$totals = calc_totals($pdo, $innings_id);

$legal_balls = (int)($totals['legal'] ?? 0);
$total_runs  = (int)($totals['runs'] ?? 0);
$total_wkts  = (int)($totals['wkts'] ?? 0);

$overs_limit   = (int)($inn['match_overs'] ?? 20);
if ($overs_limit <= 0) $overs_limit = 20;
$wickets_limit = (int)($inn['match_wickets'] ?? 10);
if ($wickets_limit <= 0) $wickets_limit = 10;
$max_balls     = $overs_limit * 6;

$is_innings_complete = false;
$is_match_ended      = false;

if ((int)$inn['innings_no'] === 1) {
    if ($legal_balls >= $max_balls || $total_wkts >= $wickets_limit) {
        $is_innings_complete = true;
    }
} else if ((int)$inn['innings_no'] === 2) {
    $target = (int)($inn['target'] ?? 0);
    if (($target > 0 && $total_runs >= $target) || $legal_balls >= $max_balls || $total_wkts >= $wickets_limit) {
        $is_innings_complete = true;
        $is_match_ended = true;
    }
}

// If current ball was a No-Ball, next ball is Free Hit!
$is_next_free_hit = ($extras_type === 'nb') ? 1 : 0;

echo json_encode([
    'success'             => true,
    'ok'                  => true,
    'seq'                 => $next_seq,
    'totals'              => $totals,
    'overs_limit'         => $overs_limit,
    'max_balls'           => $max_balls,
    'is_innings_complete' => $is_innings_complete,
    'is_match_ended'      => $is_match_ended,
    'is_free_hit'         => (bool)$is_free_hit,
    'is_next_free_hit'    => (bool)$is_next_free_hit,
    'message'             => 'Ball recorded successfully'
]);