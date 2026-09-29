<?php
// api/player_profile_get.php
// Returns permanent player profile, format-wise stats, and recent form
// GET /api/player_profile_get.php?player_id=X (or authenticated user profile)

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$player_id = (int)($_GET['player_id'] ?? 0);

if ($player_id <= 0) {
    // Fallback to current authenticated app user
    $currentUser = app_optional_auth($pdo);
    if ($currentUser) {
        $player_id = (int)$currentUser['id'];
    }
}

if ($player_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'player_id is required']);
    exit;
}

// 1. Fetch Player Personal Info (Check both players table and app_users table)
$pStmt = $pdo->prepare("SELECT * FROM players WHERE id = ?");
$pStmt->execute([$player_id]);
$player = $pStmt->fetch();

if (!$player) {
    $uStmt = $pdo->prepare("SELECT * FROM app_users WHERE id = ?");
    $uStmt->execute([$player_id]);
    $uRow = $uStmt->fetch();
    if ($uRow) {
        $player = [
            'id'             => $uRow['id'],
            'name'           => $uRow['name'] ?: 'Cricketer',
            'city'           => $uRow['city'] ?: 'India',
            'profile_pic'    => $uRow['profile_pic'],
            'role'           => $uRow['role'] ?: 'All-Rounder',
            'batting_style'  => $uRow['batting_style'] ?: 'Right-hand bat',
            'bowling_style'  => $uRow['bowling_style'] ?: 'Right-arm medium',
            'jersey_number'  => $uRow['jersey_number'] ?: '',
        ];
    }
}

if (!$player) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Player profile not found']);
    exit;
}

// 2. Compute Batting Statistics from ball_events
$batStmt = $pdo->prepare("
    SELECT 
        COUNT(DISTINCT innings_id) as innings_count,
        SUM(runs_bat) as total_runs,
        COUNT(CASE WHEN is_legal=1 THEN 1 END) as balls_faced,
        SUM(CASE WHEN runs_bat=4 THEN 1 END) as fours,
        SUM(CASE WHEN runs_bat=6 THEN 1 END) as sixes,
        MAX(runs_bat) as highest_score,
        SUM(CASE WHEN is_wicket=1 AND wicket_player_out_id=striker_id THEN 1 END) as dismissals
    FROM ball_events
    WHERE striker_id = ?
");
$batStmt->execute([$player_id]);
$bat = $batStmt->fetch();

$runs = (int)($bat['total_runs'] ?? 0);
$balls = (int)($bat['balls_faced'] ?? 0);
$dismissals = (int)($bat['dismissals'] ?? 0);
$innings = (int)($bat['innings_count'] ?? 0);

$battingAvg = $dismissals > 0 ? number_format($runs / $dismissals, 2) : number_format($runs, 2);
$battingSr = $balls > 0 ? number_format(($runs / $balls) * 100, 2) : "0.00";

// 3. Compute Bowling Statistics from ball_events
$bowlStmt = $pdo->prepare("
    SELECT 
        COUNT(DISTINCT innings_id) as innings_count,
        COUNT(CASE WHEN is_legal=1 THEN 1 END) as legal_balls,
        SUM(runs_bat + extras_runs) as runs_given,
        SUM(CASE WHEN is_wicket=1 AND wicket_type != 'run out' THEN 1 END) as wickets
    FROM ball_events
    WHERE bowler_id = ?
");
$bowlStmt->execute([$player_id]);
$bowl = $bowlStmt->fetch();

$legalBalls = (int)($bowl['legal_balls'] ?? 0);
$runsGiven = (int)($bowl['runs_given'] ?? 0);
$wickets = (int)($bowl['wickets'] ?? 0);
$oversCount = floor($legalBalls / 6) . '.' . ($legalBalls % 6);
$oversDec = $legalBalls > 0 ? $legalBalls / 6 : 0;

$bowlingEco = $oversDec > 0 ? number_format($runsGiven / $oversDec, 2) : "0.00";
$bowlingAvg = $wickets > 0 ? number_format($runsGiven / $wickets, 2) : "0.00";

// 4. Recent Matches Form (Last 5 matches)
$recentStmt = $pdo->prepare("
    SELECT b.innings_id, SUM(b.runs_bat) as runs_in_match
    FROM ball_events b
    WHERE b.striker_id = ?
    GROUP BY b.innings_id
    ORDER BY b.innings_id DESC
    LIMIT 5
");
$recentStmt->execute([$player_id]);
$recentFormRaw = $recentStmt->fetchAll();

$recentForm = [];
foreach ($recentFormRaw as $rf) {
    $recentForm[] = (int)$rf['runs_in_match'];
}

echo json_encode([
    'success' => true,
    'player'  => [
        'id'            => (int)$player['id'],
        'name'          => $player['name'] ?? 'Cricketer',
        'city'          => $player['city'] ?? 'India',
        'profile_pic'   => $player['profile_pic'] ?? null,
        'role'          => $player['role'] ?? 'All-Rounder',
        'batting_style' => $player['batting_style'] ?? 'Right-hand bat',
        'bowling_style' => $player['bowling_style'] ?? 'Right-arm medium',
        'jersey_number' => $player['jersey_number'] ?? '',
    ],
    'batting_stats' => [
        'innings'       => $innings,
        'runs'          => $runs,
        'balls'         => $balls,
        'average'       => $battingAvg,
        'strike_rate'   => $battingSr,
        'highest_score' => (int)($bat['highest_score'] ?? 0),
        'fours'         => (int)($bat['fours'] ?? 0),
        'sixes'         => (int)($bat['sixes'] ?? 0),
    ],
    'bowling_stats' => [
        'overs'   => $oversCount,
        'runs'    => $runsGiven,
        'wickets' => $wickets,
        'economy' => $bowlingEco,
        'average' => $bowlingAvg,
    ],
    'recent_form' => $recentForm,
]);
