<?php
// api/home_dashboard.php
// Aggregates data for Flutter Home Dashboard:
// - Live Matches
// - Upcoming Matches
// - Recent Results
// - Tournaments List
// - Featured Banners

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Optional auth — works for guests and logged in app users
$currentUser = app_optional_auth($pdo);

// Helper function to format match detail with team names and current scores
function formatMatchSummary(PDO $pdo, array $m): array {
    $matchId = (int)$m['id'];

    // Fetch Team A & Team B details
    $teamAStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
    $teamAStmt->execute([(int)$m['team_a_id']]);
    $teamA = $teamAStmt->fetch() ?: ['id' => $m['team_a_id'], 'name' => 'Team A', 'short_name' => 'TMA'];

    $teamBStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
    $teamBStmt->execute([(int)$m['team_b_id']]);
    $teamB = $teamBStmt->fetch() ?: ['id' => $m['team_b_id'], 'name' => 'Team B', 'short_name' => 'TMB'];

    // Fetch Tournament Name
    $tournName = 'Friendly Match';
    if (!empty($m['tournament_id'])) {
        $tStmt = $pdo->prepare("SELECT name FROM tournaments WHERE id = ?");
        $tStmt->execute([(int)$m['tournament_id']]);
        $tRow = $tStmt->fetch();
        if ($tRow) $tournName = $tRow['name'];
    }

    // Fetch Innings Scores
    $innStmt = $pdo->prepare("
        SELECT i.*, 
               (SELECT COUNT(*) FROM ball_events b WHERE b.innings_id = i.id AND b.is_legal = 1) as legal_balls,
               (SELECT SUM(b.runs_bat + b.extras_runs) FROM ball_events b WHERE b.innings_id = i.id) as runs,
               (SELECT COUNT(*) FROM ball_events b WHERE b.innings_id = i.id AND b.is_wicket = 1) as wickets
        FROM innings i
        WHERE i.match_id = ?
        ORDER BY i.innings_no ASC
    ");
    $innStmt->execute([$matchId]);
    $inningsList = $innStmt->fetchAll();

    $scores = [];
    foreach ($inningsList as $inn) {
        $legalBalls = (int)($inn['legal_balls'] ?? $inn['total_legal_balls'] ?? 0);
        $overs = floor($legalBalls / 6) + (($legalBalls % 6) / 10);
        $teamId = (int)$inn['batting_team_id'];
        $teamName = ($teamId === (int)$teamA['id']) ? ($teamA['short_name'] ?: $teamA['name']) : ($teamB['short_name'] ?: $teamB['name']);

        $scores[] = [
            'innings_no'      => (int)$inn['innings_no'],
            'batting_team_id' => $teamId,
            'batting_team'    => $teamName,
            'runs'            => (int)($inn['runs'] ?? $inn['total_runs'] ?? 0),
            'wickets'         => (int)($inn['wickets'] ?? $inn['total_wickets'] ?? 0),
            'overs'           => $overs,
            'target'          => $inn['target'] ? (int)$inn['target'] : null,
            'completed'       => (int)$inn['completed'] === 1,
        ];
    }

    // Determine Winner Name
    $winnerName = null;
    if (!empty($m['winner_team_id'])) {
        if ((int)$m['winner_team_id'] === (int)$teamA['id']) {
            $winnerName = $teamA['name'];
        } else if ((int)$m['winner_team_id'] === (int)$teamB['id']) {
            $winnerName = $teamB['name'];
        }
    }

    return [
        'id'            => $matchId,
        'tournament_name' => $tournName,
        'status'        => $m['status'], // 'scheduled', 'live', 'completed'
        'overs_limit'   => (int)$m['overs_limit'],
        'team_a'        => $teamA,
        'team_b'        => $teamB,
        'toss_winner_id'=> $m['toss_winner_team_id'] ? (int)$m['toss_winner_team_id'] : null,
        'toss_decision' => $m['toss_decision'] ?? null,
        'winner_id'      => $m['winner_team_id'] ? (int)$m['winner_team_id'] : null,
        'winner_name'   => $winnerName,
        'result_type'   => $m['result_type'] ?? null,
        'scores'        => $scores,
        'created_at'    => $m['created_at'] ?? null,
    ];
}

// 1. Live Matches
$liveStmt = $pdo->query("SELECT * FROM matches WHERE status IN ('live', 'in_progress') ORDER BY id DESC LIMIT 5");
$rawLive  = $liveStmt->fetchAll();
$liveMatches = [];
foreach ($rawLive as $m) {
    $liveMatches[] = formatMatchSummary($pdo, $m);
}

// 2. Upcoming Matches
$upStmt = $pdo->query("SELECT * FROM matches WHERE status IN ('scheduled', 'upcoming') ORDER BY id ASC LIMIT 5");
$rawUp  = $upStmt->fetchAll();
$upcomingMatches = [];
foreach ($rawUp as $m) {
    $upcomingMatches[] = formatMatchSummary($pdo, $m);
}

// 3. Recent Results
$recStmt = $pdo->query("SELECT * FROM matches WHERE status IN ('completed', 'finished') ORDER BY id DESC LIMIT 5");
$rawRec  = $recStmt->fetchAll();
$recentResults = [];
foreach ($rawRec as $m) {
    $recentResults[] = formatMatchSummary($pdo, $m);
}

// 4. Active Tournaments
$tournStmt = $pdo->query("
    SELECT t.*,
           (SELECT COUNT(*) FROM teams tm WHERE tm.tournament_id = t.id) as total_teams,
           (SELECT COUNT(*) FROM matches m WHERE m.tournament_id = t.id) as total_matches
    FROM tournaments t
    ORDER BY t.id DESC LIMIT 6
");
$tournaments = $tournStmt->fetchAll();

// 5. App Banners (Dynamic)
$banners = [
    [
        'id'          => 1,
        'title'       => 'SB CricScore Live Tournament',
        'subtitle'    => 'Register your squad & compete with top teams!',
        'button_text' => 'Explore Tournaments',
        'image_url'   => 'assets/banner1.png'
    ],
    [
        'id'          => 2,
        'title'       => 'Ball-by-Ball Live Scoring',
        'subtitle'    => 'Real-time commentary & instant scorecards',
        'button_text' => 'Watch Live',
        'image_url'   => 'assets/banner2.png'
    ]
];

echo json_encode([
    'success'          => true,
    'user'             => $currentUser ? [
        'id'   => (int)$currentUser['id'],
        'name' => $currentUser['name'],
        'city' => $currentUser['city']
    ] : null,
    'live_matches'     => $liveMatches,
    'upcoming_matches' => $upcomingMatches,
    'recent_results'   => $recentResults,
    'tournaments'      => $tournaments,
    'banners'          => $banners
]);
