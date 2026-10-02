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

$scorer_pid    = (int)($input['scorer_player_id'] ?? 0);
$toss_caller   = (int)($input['toss_caller_team_id'] ?? 0);
$toss_call     = trim($input['toss_call'] ?? '');
$toss_result   = trim($input['toss_result'] ?? '');

try {
    // Auto-migrate columns if missing
    try {
        $mCols = [];
        $st = $pdo->query("SHOW COLUMNS FROM matches");
        while ($r = $st->fetch(PDO::FETCH_ASSOC)) { $mCols[strtolower($r['Field'])] = true; }
        if (!isset($mCols['toss_caller_team_id'])) $pdo->exec("ALTER TABLE matches ADD COLUMN toss_caller_team_id INT DEFAULT NULL");
        if (!isset($mCols['toss_call'])) $pdo->exec("ALTER TABLE matches ADD COLUMN toss_call VARCHAR(20) DEFAULT NULL");
        if (!isset($mCols['toss_result'])) $pdo->exec("ALTER TABLE matches ADD COLUMN toss_result VARCHAR(20) DEFAULT NULL");
        
        $iCols = [];
        $st2 = $pdo->query("SHOW COLUMNS FROM innings");
        while ($r2 = $st2->fetch(PDO::FETCH_ASSOC)) { $iCols[strtolower($r2['Field'])] = true; }
        if (!isset($iCols['scorer_player_id'])) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_player_id INT DEFAULT NULL");
    } catch (Throwable $e) {}

    $pdo->beginTransaction();

    // Resolve scorer name and mobile if player ID provided
    $scorerName = null;
    $scorerMobile = null;
    if ($scorer_pid > 0) {
        $pSt = $pdo->prepare("SELECT name, mobile FROM players WHERE id = ?");
        $pSt->execute([$scorer_pid]);
        $pRow = $pSt->fetch(PDO::FETCH_ASSOC);
        if ($pRow) {
            $scorerName = $pRow['name'];
            $scorerMobile = $pRow['mobile'] ?? null;
        }
    }

    $scorerPin = (string)mt_rand(1000, 9999);

    // Create or Reset Innings 1
    $chk1 = $pdo->prepare("SELECT id FROM innings WHERE match_id=? AND innings_no=1");
    $chk1->execute([$match_id]);
    $i1 = $chk1->fetch(PDO::FETCH_ASSOC);
    if (!$i1) {
        $ins1 = $pdo->prepare("INSERT INTO innings(match_id, innings_no, batting_team_id, bowling_team_id, scorer_player_id, scorer_name, scorer_mobile, completed) VALUES(?, 1, ?, ?, ?, ?, ?, 0)");
        $ins1->execute([$match_id, $bat_first, $bowling, ($scorer_pid > 0 ? $scorer_pid : null), $scorerName, $scorerMobile]);
        $inn1_id = (int)$pdo->lastInsertId();
    } else {
        $pdo->prepare("UPDATE innings SET batting_team_id=?, bowling_team_id=?, scorer_player_id=?, scorer_name=?, scorer_mobile=?, completed=0, target=NULL WHERE id=?")->execute([$bat_first, $bowling, ($scorer_pid > 0 ? $scorer_pid : null), $scorerName, $scorerMobile, $i1['id']]);
        $inn1_id = (int)$i1['id'];
    }

    // Delete any premature/dummy Innings 2+ (Innings 2 must only be created when Innings 1 is completed!)
    $pdo->prepare("DELETE FROM innings WHERE match_id=? AND innings_no > 1")->execute([$match_id]);

    // Update Match status to live with toss and active scorer details
    $upd = $pdo->prepare("UPDATE matches SET status='live', toss_winner_team_id=?, toss_decision=?, toss_caller_team_id=?, toss_call=?, toss_result=?, active_scorer_player_id=?, active_scorer_name=?, active_scorer_mobile=?, scorer_pin=? WHERE id=?");
    $upd->execute([
        $toss_winner,
        $toss_decision,
        ($toss_caller > 0 ? $toss_caller : null),
        ($toss_call ?: null),
        ($toss_result ?: null),
        ($scorer_pid > 0 ? $scorer_pid : null),
        $scorerName,
        $scorerMobile,
        $scorerPin,
        $match_id
    ]);

    $pdo->commit();

    echo json_encode([
        'success'              => true,
        'ok'                   => true,
        'match_id'             => $match_id,
        'innings_id'           => $inn1_id,
        'batting_team'         => $bat_first,
        'bowling_team'         => $bowling,
        'scorer_player_id'     => $scorer_pid,
        'active_scorer_name'   => $scorerName,
        'active_scorer_mobile' => $scorerMobile,
        'scorer_pin'           => $scorerPin,
        'message'              => 'Match started successfully! 🏏'
    ]);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
