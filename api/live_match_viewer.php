<?php
// api/live_match_viewer.php
// Real-time Spectator Match Center & Live Commentary API
// GET /api/live_match_viewer.php?match_id=X

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$match_id = (int)($_GET['match_id'] ?? 0);
if ($match_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_id is required']);
    exit;
}

// 1. Fetch Match
$mStmt = $pdo->prepare("SELECT * FROM matches WHERE id = ?");
$mStmt->execute([$match_id]);
$m = $mStmt->fetch();

if (!$m) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Match not found']);
    exit;
}

// Teams
$teamAStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
$teamAStmt->execute([(int)$m['team_a_id']]);
$teamA = $teamAStmt->fetch() ?: ['id' => $m['team_a_id'], 'name' => 'Team A', 'short_name' => 'TMA'];

$teamBStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
$teamBStmt->execute([(int)$m['team_b_id']]);
$teamB = $teamBStmt->fetch() ?: ['id' => $m['team_b_id'], 'name' => 'Team B', 'short_name' => 'TMB'];

// 2. Fetch Active Innings
$innStmt = $pdo->prepare("SELECT * FROM innings WHERE match_id = ? ORDER BY innings_no DESC LIMIT 1");
$innStmt->execute([$match_id]);
$inn = $innStmt->fetch();

$runs = 0;
$wickets = 0;
$legalBalls = 0;
$target = null;
$commentaryList = [];
$currentBatters = [];
$currentBowler = null;

if ($inn) {
    $innId = (int)$inn['id'];
    $target = $inn['target'] ? (int)$inn['target'] : null;

    // Totals
    $tStmt = $pdo->prepare("
        SELECT 
            COUNT(CASE WHEN is_legal=1 THEN 1 END) as legal,
            SUM(runs_bat + extras_runs) as total_runs,
            SUM(CASE WHEN is_wicket=1 THEN 1 END) as total_wkts
        FROM ball_events WHERE innings_id = ?
    ");
    $tStmt->execute([$innId]);
    $tRow = $tStmt->fetch();

    $runs = (int)($tRow['total_runs'] ?? 0);
    $wickets = (int)($tRow['total_wkts'] ?? 0);
    $legalBalls = (int)($tRow['legal'] ?? 0);

    // Recent 10 balls commentary
    $cStmt = $pdo->prepare("
        SELECT b.*,
               (SELECT name FROM players p WHERE p.id = b.striker_id) as striker_name,
               (SELECT name FROM players p WHERE p.id = b.bowler_id) as bowler_name
        FROM ball_events b
        WHERE b.innings_id = ?
        ORDER BY b.seq DESC
        LIMIT 15
    ");
    $cStmt->execute([$innId]);
    $rawBalls = $cStmt->fetchAll();

    foreach ($rawBalls as $b) {
        $overNo = floor(($b['seq'] - 1) / 6);
        $ballNo = (($b['seq'] - 1) % 6) + 1;
        $overBall = "$overNo.$ballNo";

        $desc = "Runs: {$b['runs_bat']}";
        if ($b['is_wicket'] == 1) {
            $desc = "OUT! (" . ($b['wicket_type'] ?: 'Wicket') . ")";
        } else if ($b['extras_type'] === 'wd') {
            $desc = "WIDE ball (+{$b['extras_runs']} run)";
        } else if ($b['extras_type'] === 'nb') {
            $desc = "NO BALL (+{$b['extras_runs']} run)";
        } else if ($b['runs_bat'] == 4) {
            $desc = "FOUR! Cracking shot by " . ($b['striker_name'] ?: 'Batter');
        } else if ($b['runs_bat'] == 6) {
            $desc = "SIX! Huge hit over the boundary!";
        }

        $commentaryList[] = [
            'seq'       => (int)$b['seq'],
            'over_ball' => $overBall,
            'striker'   => $b['striker_name'] ?: 'Batter',
            'bowler'    => $b['bowler_name'] ?: 'Bowler',
            'event'     => $desc,
            'runs'      => (int)$b['runs_bat'],
            'is_wicket' => (int)$b['is_wicket'] === 1,
        ];
    }
}

// Overs formatting
$oversFormatted = floor($legalBalls / 6) . '.' . ($legalBalls % 6);
$oversDec = $legalBalls > 0 ? $legalBalls / 6 : 0;
$crr = $oversDec > 0 ? number_format($runs / $oversDec, 2) : "0.00";

$rrr = "0.00";
$reqRuns = 0;
$remBalls = 0;
if ($target && $m['overs_limit']) {
    $reqRuns = max(0, $target - $runs);
    $totalAllowedBalls = (int)$m['overs_limit'] * 6;
    $remBalls = max(0, $totalAllowedBalls - $legalBalls);
    $rrr = ($remBalls > 0) ? number_format(($reqRuns / $remBalls) * 6, 2) : "0.00";
}

// Scorer Permission Check for Logged In App User
$currentUser = app_optional_auth($pdo);
$isScorer = false;

$activeScorerId = $m['active_scorer_player_id'] ? (int)$m['active_scorer_player_id'] : null;
$activeScorerMob = $m['active_scorer_mobile'] ?? '';
$activeScorerName = $m['active_scorer_name'] ?? '';

if ($currentUser) {
    $uId = (int)$currentUser['id'];
    $uMob = trim($currentUser['mobile'] ?? ($currentUser['phone'] ?? ''));
    $cleanUMob = preg_replace('/\D+/', '', $uMob);
    $last10U = (strlen($cleanUMob) >= 10) ? substr($cleanUMob, -10) : $cleanUMob;

    if (!empty($activeScorerMob) && !empty($last10U)) {
        $cleanScorerMob = preg_replace('/\D+/', '', $activeScorerMob);
        $last10S = (strlen($cleanScorerMob) >= 10) ? substr($cleanScorerMob, -10) : $cleanScorerMob;
        if ($last10U === $last10S) {
            $isScorer = true;
        }
    }

    if (!$isScorer && $activeScorerId > 0) {
        $pCheck = $pdo->prepare("SELECT mobile, name FROM players WHERE id = ?");
        $pCheck->execute([$activeScorerId]);
        $pRow = $pCheck->fetch(PDO::FETCH_ASSOC);
        if ($pRow) {
            $pMob = preg_replace('/\D+/', '', $pRow['mobile'] ?? '');
            $last10P = (strlen($pMob) >= 10) ? substr($pMob, -10) : $pMob;
            if (!empty($last10U) && $last10U === $last10P) {
                $isScorer = true;
            } else if (!empty($currentUser['name']) && strtolower(trim($currentUser['name'])) === strtolower(trim($pRow['name']))) {
                $isScorer = true;
            }
        }
    }

    if (!$isScorer && ($activeScorerId === null || $activeScorerId <= 0)) {
        $tCheck = $pdo->prepare("SELECT owner_id FROM teams WHERE id IN (?, ?)");
        $tCheck->execute([(int)$m['team_a_id'], (int)$m['team_b_id']]);
        while ($r = $tCheck->fetch(PDO::FETCH_ASSOC)) {
            if ((int)($r['owner_id'] ?? 0) === $uId) {
                $isScorer = true;
                break;
            }
        }
    }
}

echo json_encode([
    'success'                  => true,
    'match_id'                 => $match_id,
    'status'                   => $m['status'],
    'team_a'                   => $teamA,
    'team_b'                   => $teamB,
    'active_innings_id'        => $inn ? (int)$inn['id'] : 0,
    'active_innings_no'        => $inn ? (int)$inn['innings_no'] : 1,
    'batting_team_id'          => $inn ? (int)$inn['batting_team_id'] : (int)$teamA['id'],
    'bowling_team_id'          => $inn ? (int)$inn['bowling_team_id'] : (int)$teamB['id'],
    'batting_team'             => $inn ? (($inn['batting_team_id'] == $teamA['id']) ? $teamA['name'] : $teamB['name']) : 'TBD',
    'active_scorer_player_id'  => $activeScorerId,
    'active_scorer_name'       => $activeScorerName,
    'is_current_user_scorer'   => $isScorer,
    'runs'                     => $runs,
    'wickets'                  => $wickets,
    'overs'                    => $oversFormatted,
    'overs_limit'              => (int)$m['overs_limit'],
    'target'                   => $target,
    'crr'                      => $crr,
    'rrr'                      => $rrr,
    'runs_required'            => $reqRuns,
    'balls_remaining'          => $remBalls,
    'youtube_url'              => $m['youtube_url'] ?? null,
    'commentary'               => $commentaryList,
]);
