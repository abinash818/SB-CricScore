<?php
// api/innings_complete.php
// Marks an innings as complete, sets up chase / Innings 2 or finalizes match.
// Accepts JSON or Form-Data (Web and Mobile App compatible).

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/_helpers.php';
require_once __DIR__ . '/app_auth.php';

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;

$innings_id = (int)($input['innings_id'] ?? 0);
$scorer_player_id = (int)($input['scorer_player_id'] ?? 0);

if ($innings_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'innings_id is required']);
    exit;
}

// 1. Fetch Innings details
$st = $pdo->prepare("SELECT * FROM innings WHERE id=?");
$st->execute([$innings_id]);
$inn = $st->fetch(PDO::FETCH_ASSOC);

if (!$inn) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Innings not found']);
    exit;
}

$match_id = (int)$inn['match_id'];
$innings_no = (int)$inn['innings_no'];

// 2. Complete Innings
$res = complete_innings($pdo, $innings_id);

if (isset($res['error'])) {
    http_response_code($res['code'] ?? 400);
    echo json_encode(['success' => false, 'error' => $res['error']]);
    exit;
}

// 3. If Innings 1 was completed, find Innings 2 ID and optionally assign scorer_player_id
$innings2_id = 0;
$target = (int)($res['target'] ?? 0);
$bat_id = 0;
$bowl_id = 0;

if ($innings_no === 1) {
    $st2 = $pdo->prepare("SELECT * FROM innings WHERE match_id=? AND innings_no=2");
    $st2->execute([$match_id]);
    $i2 = $st2->fetch(PDO::FETCH_ASSOC);
    if ($i2) {
        $innings2_id = (int)$i2['id'];
        $bat_id = (int)$i2['batting_team_id'];
        $bowl_id = (int)$i2['bowling_team_id'];
        if ($scorer_player_id > 0) {
            try {
                $pdo->prepare("UPDATE innings SET scorer_player_id=? WHERE id=?")->execute([$scorer_player_id, $innings2_id]);
            } catch (Throwable $e) {}
        }
    }
}

echo json_encode(array_merge($res, [
    'success'          => true,
    'ok'               => true,
    'match_id'         => $match_id,
    'completed_innings'=> $innings_id,
    'innings_id'       => $innings2_id > 0 ? $innings2_id : $innings_id,
    'innings2_id'      => $innings2_id,
    'target'           => $target,
    'batting_team_id'  => $bat_id,
    'bowling_team_id'  => $bowl_id,
    'message'          => 'Innings completed successfully'
]));
