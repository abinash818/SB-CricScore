<?php
// api/scorecard_get.php
// Returns complete match scorecard (Batting, Bowling, Extras, FOW)
// GET /api/scorecard_get.php?match_id=X

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';

$match_id = (int)($_GET['match_id'] ?? 0);
if ($match_id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_id is required']);
    exit;
}

// Fetch Innings 1 & 2
$innStmt = $pdo->prepare("SELECT * FROM innings WHERE match_id = ? ORDER BY innings_no ASC");
$innStmt->execute([$match_id]);
$inningsList = $innStmt->fetchAll();

$scorecardData = [];

foreach ($inningsList as $inn) {
    $innId = (int)$inn['id'];

    // Batting Team & Bowling Team Names
    $batTeamStmt = $pdo->prepare("SELECT id, name, short_name FROM teams WHERE id = ?");
    $batTeamStmt->execute([(int)$inn['batting_team_id']]);
    $batTeam = $batTeamStmt->fetch() ?: ['name' => 'Batting Team'];

    // Batting Scorecard
    $batStmt = $pdo->prepare("
        SELECT b.striker_id,
               p.name as batter_name,
               SUM(b.runs_bat) as runs,
               COUNT(CASE WHEN b.is_legal=1 THEN 1 END) as balls,
               SUM(CASE WHEN b.runs_bat=4 THEN 1 END) as fours,
               SUM(CASE WHEN b.runs_bat=6 THEN 1 END) as sixes,
               MAX(CASE WHEN b.is_wicket=1 AND b.wicket_player_out_id=b.striker_id THEN b.wicket_type ELSE NULL END) as dismissal
        FROM ball_events b
        LEFT JOIN players p ON p.id = b.striker_id
        WHERE b.innings_id = ? AND b.striker_id IS NOT NULL
        GROUP BY b.striker_id
    ");
    $batStmt->execute([$innId]);
    $batters = $batStmt->fetchAll();

    $battingList = [];
    foreach ($batters as $bt) {
        $r = (int)($bt['runs'] ?? 0);
        $b = (int)($bt['balls'] ?? 0);
        $sr = $b > 0 ? number_format(($r / $b) * 100, 2) : "0.00";

        $battingList[] = [
            'player_id' => (int)$bt['striker_id'],
            'name'      => $bt['batter_name'] ?: 'Batter',
            'runs'      => $r,
            'balls'     => $b,
            'fours'     => (int)($bt['fours'] ?? 0),
            'sixes'     => (int)($bt['sixes'] ?? 0),
            'sr'        => $sr,
            'dismissal' => $bt['dismissal'] ?: 'not out',
        ];
    }

    // Bowling Scorecard
    $bowlStmt = $pdo->prepare("
        SELECT b.bowler_id,
               p.name as bowler_name,
               COUNT(CASE WHEN b.is_legal=1 THEN 1 END) as legal_balls,
               SUM(b.runs_bat + b.extras_runs) as runs_given,
               SUM(CASE WHEN b.is_wicket=1 AND b.wicket_type != 'run out' THEN 1 END) as wickets
        FROM ball_events b
        LEFT JOIN players p ON p.id = b.bowler_id
        WHERE b.innings_id = ? AND b.bowler_id IS NOT NULL
        GROUP BY b.bowler_id
    ");
    $bowlStmt->execute([$innId]);
    $bowlers = $bowlStmt->fetchAll();

    $bowlingList = [];
    foreach ($bowlers as $bw) {
        $lb = (int)($bw['legal_balls'] ?? 0);
        $rg = (int)($bw['runs_given'] ?? 0);
        $wk = (int)($bw['wickets'] ?? 0);
        $ov = floor($lb / 6) . '.' . ($lb % 6);
        $ovDec = $lb > 0 ? $lb / 6 : 0;
        $eco = $ovDec > 0 ? number_format($rg / $ovDec, 2) : "0.00";

        $bowlingList[] = [
            'player_id'  => (int)$bw['bowler_id'],
            'name'       => $bw['bowler_name'] ?: 'Bowler',
            'overs'      => $ov,
            'runs'       => $rg,
            'wickets'    => $wk,
            'economy'    => $eco,
        ];
    }

    $scorecardData[] = [
        'innings_no'   => (int)$inn['innings_no'],
        'batting_team' => $batTeam['name'],
        'batting'      => $battingList,
        'bowling'      => $bowlingList,
    ];
}

echo json_encode([
    'success'   => true,
    'match_id'  => $match_id,
    'scorecard' => $scorecardData,
]);
