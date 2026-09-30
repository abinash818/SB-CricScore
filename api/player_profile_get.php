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

$currentUser = app_optional_auth($pdo);
$hasExplicitPlayerId = isset($_GET['player_id']) && (int)$_GET['player_id'] > 0;
$reqPlayerId = $hasExplicitPlayerId ? (int)$_GET['player_id'] : 0;

$player = null;
$pName = '';
$pMobile = '';

if (!$hasExplicitPlayerId && $currentUser) {
    // 1. Current Authenticated App User's Own Profile
    $player = [
        'id'             => (int)$currentUser['id'],
        'user_id'        => (int)$currentUser['id'],
        'mobile'         => $currentUser['mobile'] ?? '',
        'name'           => $currentUser['name'] ?: 'Cricketer',
        'city'           => $currentUser['city'] ?: 'India',
        'profile_pic'    => $currentUser['profile_pic'],
        'role'           => $currentUser['role'] ?: 'All-Rounder',
        'batting_style'  => $currentUser['batting_style'] ?: 'Right Hand Bat',
        'bowling_style'  => $currentUser['bowling_style'] ?: 'Right Arm Medium',
        'jersey_number'  => $currentUser['jersey_number'] ?: '',
    ];
    $pName = $currentUser['name'] ?? '';
    $pMobile = $currentUser['mobile'] ?? '';
} else if ($hasExplicitPlayerId) {
    // 2. Specific Player requested (from tournament squad/match scorecard)
    $pStmt = $pdo->prepare("SELECT * FROM players WHERE id = ?");
    $pStmt->execute([$reqPlayerId]);
    $pRow = $pStmt->fetch(PDO::FETCH_ASSOC);

    if ($pRow) {
        $player = [
            'id'             => (int)$pRow['id'],
            'name'           => $pRow['name'] ?? '',
            'city'           => !empty($pRow['pob']) ? $pRow['pob'] : (!empty($pRow['city']) ? $pRow['city'] : 'India'),
            'profile_pic'    => $pRow['profile_pic'] ?? null,
            'role'           => $pRow['role'] ?? 'All-Rounder',
            'batting_style'  => $pRow['batting_style'] ?? 'Right Hand Bat',
            'bowling_style'  => $pRow['bowling_style'] ?? 'Right Arm Medium',
            'jersey_number'  => $pRow['jersey_number'] ?? '',
        ];
        $pName = $pRow['name'] ?? '';
        $pMobile = $pRow['mobile'] ?? '';

        // If player has mobile, sync with app_users record for newest details
        if (!empty($pMobile)) {
            $uStmt = $pdo->prepare("SELECT * FROM app_users WHERE mobile = ?");
            $uStmt->execute([$pMobile]);
            $uRow = $uStmt->fetch(PDO::FETCH_ASSOC);
            if ($uRow) {
                if (!empty($uRow['name'])) $player['name'] = $uRow['name'];
                if (!empty($uRow['city'])) $player['city'] = $uRow['city'];
                if (!empty($uRow['profile_pic'])) $player['profile_pic'] = $uRow['profile_pic'];
                if (!empty($uRow['role'])) $player['role'] = $uRow['role'];
                if (!empty($uRow['batting_style'])) $player['batting_style'] = $uRow['batting_style'];
                if (!empty($uRow['bowling_style'])) $player['bowling_style'] = $uRow['bowling_style'];
                if (!empty($uRow['jersey_number'])) $player['jersey_number'] = $uRow['jersey_number'];
            }
        }
    } else {
        // Check if reqPlayerId is an app_users ID
        $uStmt = $pdo->prepare("SELECT * FROM app_users WHERE id = ?");
        $uStmt->execute([$reqPlayerId]);
        $uRow = $uStmt->fetch(PDO::FETCH_ASSOC);
        if ($uRow) {
            $player = [
                'id'             => (int)$uRow['id'],
                'name'           => $uRow['name'] ?: 'Cricketer',
                'city'           => $uRow['city'] ?: 'India',
                'profile_pic'    => $uRow['profile_pic'],
                'role'           => $uRow['role'] ?: 'All-Rounder',
                'batting_style'  => $uRow['batting_style'] ?: 'Right Hand Bat',
                'bowling_style'  => $uRow['bowling_style'] ?: 'Right Arm Medium',
                'jersey_number'  => $uRow['jersey_number'] ?: '',
            ];
            $pName = $uRow['name'] ?? '';
            $pMobile = $uRow['mobile'] ?? '';
        }
    }
} else if ($currentUser) {
    $player = [
        'id'             => (int)$currentUser['id'],
        'name'           => $currentUser['name'] ?: 'Cricketer',
        'city'           => $currentUser['city'] ?: 'India',
        'profile_pic'    => $currentUser['profile_pic'],
        'role'           => $currentUser['role'] ?: 'All-Rounder',
        'batting_style'  => $currentUser['batting_style'] ?: 'Right Hand Bat',
        'bowling_style'  => $currentUser['bowling_style'] ?: 'Right Arm Medium',
        'jersey_number'  => $currentUser['jersey_number'] ?: '',
    ];
    $pName = $currentUser['name'] ?? '';
    $pMobile = $currentUser['mobile'] ?? '';
}

if (!$player) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Player profile not found']);
    exit;
}

// Find all player IDs associated with this name OR mobile across tournaments for career stats aggregation
$allIds = [];
if ($hasExplicitPlayerId) {
    $allIds[] = $reqPlayerId;
}
if (!empty($pName)) {
    $idsStmt = $pdo->prepare("SELECT id FROM players WHERE name = ?");
    $idsStmt->execute([$pName]);
    $fetchedIds = $idsStmt->fetchAll(PDO::FETCH_COLUMN);
    if (!empty($fetchedIds)) {
        $allIds = array_merge($allIds, array_map('intval', $fetchedIds));
    }
}
if (!empty($pMobile)) {
    $mIdsStmt = $pdo->prepare("SELECT id FROM players WHERE mobile = ?");
    $mIdsStmt->execute([$pMobile]);
    $mFetchedIds = $mIdsStmt->fetchAll(PDO::FETCH_COLUMN);
    if (!empty($mFetchedIds)) {
        $allIds = array_merge($allIds, array_map('intval', $mFetchedIds));
    }
}
$allIds = array_values(array_unique(array_filter($allIds, fn($id) => $id > 0)));
$inClause = !empty($allIds) ? implode(',', $allIds) : '0';


// 2. Compute Batting Statistics from ball_events
$batStmt = $pdo->query("
    SELECT 
        COUNT(DISTINCT m.id) as match_count,
        COUNT(DISTINCT b.innings_id) as innings_count,
        SUM(b.runs_bat) as total_runs,
        COUNT(CASE WHEN b.is_legal=1 THEN 1 END) as balls_faced,
        SUM(CASE WHEN b.runs_bat=4 THEN 1 END) as fours,
        SUM(CASE WHEN b.runs_bat=6 THEN 1 END) as sixes
    FROM ball_events b
    JOIN innings i ON b.innings_id = i.id
    JOIN matches m ON i.match_id = m.id
    WHERE b.striker_id IN ($inClause)
");
$bat = $batStmt ? $batStmt->fetch(PDO::FETCH_ASSOC) : [];

// Batting History per innings for HS, 50s, 100s, not-outs
$batHistStmt = $pdo->query("
    SELECT SUM(b.runs_bat) as runs, 
           MAX(CASE WHEN b.is_wicket=1 AND b.wicket_player_out_id IN ($inClause) THEN 1 ELSE 0 END) as is_out
    FROM ball_events b 
    WHERE b.striker_id IN ($inClause)
    GROUP BY b.innings_id
");
$batHist = $batHistStmt ? $batHistStmt->fetchAll(PDO::FETCH_ASSOC) : [];

$hs = 0; $fifties = 0; $hundreds = 0; $bat_innings = 0; $not_outs = 0;
foreach ($batHist as $h) {
    $r = (int)($h['runs'] ?? 0);
    if ($r > $hs) $hs = $r;
    if ($r >= 50 && $r < 100) $fifties++;
    if ($r >= 100) $hundreds++;
    if ((int)($h['is_out'] ?? 0) === 0) $not_outs++;
    $bat_innings++;
}

$runs = (int)($bat['total_runs'] ?? 0);
$balls = (int)($bat['balls_faced'] ?? 0);
$outs = $bat_innings - $not_outs;
$battingAvg = $outs > 0 ? number_format($runs / $outs, 2) : number_format($runs, 2);
$battingSr = $balls > 0 ? number_format(($runs / $balls) * 100, 2) : "0.00";

// 3. Compute Bowling Statistics from ball_events
$bowlStmt = $pdo->query("
    SELECT 
        COUNT(DISTINCT m.id) as match_count,
        COUNT(DISTINCT b.innings_id) as innings_count,
        COUNT(CASE WHEN b.is_legal=1 THEN 1 END) as legal_balls,
        SUM(b.runs_bat + b.extras_runs) as runs_given,
        SUM(CASE WHEN b.is_wicket=1 AND b.wicket_type != 'run out' THEN 1 END) as wickets,
        COUNT(CASE WHEN b.extras_type='wd' THEN 1 END) as wides,
        COUNT(CASE WHEN b.extras_type='nb' THEN 1 END) as no_balls
    FROM ball_events b
    JOIN innings i ON b.innings_id = i.id
    JOIN matches m ON i.match_id = m.id
    WHERE b.bowler_id IN ($inClause)
");
$bowl = $bowlStmt ? $bowlStmt->fetch(PDO::FETCH_ASSOC) : [];

$bowlHistStmt = $pdo->query("
    SELECT 
        COUNT(CASE WHEN is_wicket=1 AND wicket_type != 'run out' THEN 1 END) as wkts,
        SUM(runs_bat + extras_runs) as runs
    FROM ball_events
    WHERE bowler_id IN ($inClause)
    GROUP BY innings_id
");
$bowlHist = $bowlHistStmt ? $bowlHistStmt->fetchAll(PDO::FETCH_ASSOC) : [];

$best_wkts = 0; $best_runs = 9999;
$w3 = 0; $w5 = 0;
foreach ($bowlHist as $bh) {
    $w = (int)($bh['wkts'] ?? 0);
    $r = (int)($bh['runs'] ?? 0);
    if ($w > $best_wkts) {
        $best_wkts = $w;
        $best_runs = $r;
    } elseif ($w === $best_wkts && $w > 0 && $r < $best_runs) {
        $best_runs = $r;
    }
    if ($w >= 3) $w3++;
    if ($w >= 5) $w5++;
}
$bbi = ($best_wkts > 0) ? "$best_wkts/$best_runs" : "-";

$legalBalls = (int)($bowl['legal_balls'] ?? 0);
$runsGiven = (int)($bowl['runs_given'] ?? 0);
$wickets = (int)($bowl['wickets'] ?? 0);
$oversCount = floor($legalBalls / 6) . '.' . ($legalBalls % 6);
$oversDec = $legalBalls > 0 ? $legalBalls / 6 : 0;

$bowlingEco = $oversDec > 0 ? number_format($runsGiven / $oversDec, 2) : "0.00";
$bowlingAvg = $wickets > 0 ? number_format($runsGiven / $wickets, 2) : "0.00";
$bowlingSr = $wickets > 0 ? number_format($legalBalls / $wickets, 1) : "0.0";

// Total matches
$totalMatches = max((int)($bat['match_count'] ?? 0), (int)($bowl['match_count'] ?? 0));

// 4. Recent Matches Form (Last 10 matches)
$recentStmt = $pdo->query("
    SELECT b.innings_id, SUM(b.runs_bat) as runs_in_match
    FROM ball_events b
    WHERE b.striker_id IN ($inClause)
    GROUP BY b.innings_id
    ORDER BY b.innings_id DESC
    LIMIT 10
");
$recentFormRaw = $recentStmt ? $recentStmt->fetchAll(PDO::FETCH_ASSOC) : [];

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
        'total_matches' => $totalMatches,
    ],
    'batting_stats' => [
        'matches'       => (int)($bat['match_count'] ?? 0),
        'innings'       => $bat_innings,
        'runs'          => $runs,
        'balls'         => $balls,
        'average'       => $battingAvg,
        'strike_rate'   => $battingSr,
        'highest_score' => $hs,
        'fifties'       => $fifties,
        'hundreds'      => $hundreds,
        'not_outs'      => $not_outs,
        'fours'         => (int)($bat['fours'] ?? 0),
        'sixes'         => (int)($bat['sixes'] ?? 0),
    ],
    'bowling_stats' => [
        'matches'       => (int)($bowl['match_count'] ?? 0),
        'innings'       => count($bowlHist),
        'overs'         => $oversCount,
        'legal_balls'   => $legalBalls,
        'runs'          => $runsGiven,
        'wickets'       => $wickets,
        'economy'       => $bowlingEco,
        'average'       => $bowlingAvg,
        'strike_rate'   => $bowlingSr,
        'best_bowling'  => $bbi,
        'three_wickets' => $w3,
        'five_wickets'  => $w5,
        'wides'         => (int)($bowl['wides'] ?? 0),
        'no_balls'      => (int)($bowl['no_balls'] ?? 0),
    ],
    'recent_form' => $recentForm,
]);
