<?php
// api/home_dashboard.php
// Aggregates filtered data for Flutter Home Dashboard:
// - Filter by "my_matches", "district", or "all"
// - Location-aware filtering for Tournaments, Friendly Matches, and Live Scorer Feeds.

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Optional auth
$currentUser = app_optional_auth($pdo);

$filter   = trim($_GET['filter'] ?? 'my_matches'); // 'my_matches', 'district', 'all'
$district = trim($_GET['district'] ?? ($currentUser['district'] ?? $currentUser['city'] ?? 'Coimbatore'));
$state    = trim($_GET['state'] ?? ($currentUser['state'] ?? 'Tamil Nadu'));
$phone    = trim($_GET['phone'] ?? ($currentUser['mobile'] ?? ''));

// 1. Identify User's Teams for "My Matches"
$myTeamIds = [];
$cleanPhone = '';
if (!empty($phone)) {
    $cleanPhone = substr(preg_replace('/[^0-9]/', '', $phone), -10);
}
if (empty($cleanPhone) && $currentUser && !empty($currentUser['mobile'])) {
    $cleanPhone = substr(preg_replace('/[^0-9]/', '', $currentUser['mobile']), -10);
}

if (!empty($cleanPhone)) {
    // Player / Captain in teams
    $pStmt = $pdo->prepare("SELECT DISTINCT team_id FROM players WHERE mobile LIKE ?");
    $pStmt->execute(["%$cleanPhone%"]);
    while ($r = $pStmt->fetch(PDO::FETCH_ASSOC)) {
        $myTeamIds[] = (int)$r['team_id'];
    }

    // Teams from match_playing_xi where user's player was included
    $xiStmt = $pdo->prepare("SELECT DISTINCT team_id FROM match_playing_xi WHERE player_id IN (SELECT id FROM players WHERE mobile LIKE ?)");
    $xiStmt->execute(["%$cleanPhone%"]);
    while ($r = $xiStmt->fetch(PDO::FETCH_ASSOC)) {
        $myTeamIds[] = (int)$r['team_id'];
    }
}

if ($currentUser && !empty($currentUser['id'])) {
    $tOwn = $pdo->prepare("SELECT id FROM teams WHERE owner_id = ?");
    $tOwn->execute([(int)$currentUser['id']]);
    while ($r = $tOwn->fetch(PDO::FETCH_ASSOC)) {
        $myTeamIds[] = (int)$r['id'];
    }
}
$myTeamIds = array_values(array_unique(array_filter($myTeamIds)));

// Helper function to format match detail with team names and current scores
function formatMatchSummary(PDO $pdo, array $m): array {
    $matchId = (int)$m['id'];

    // Fetch Team A & Team B details
    $teamAStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
    $teamAStmt->execute([(int)$m['team_a_id']]);
    $teamA = $teamAStmt->fetch(PDO::FETCH_ASSOC) ?: ['id' => $m['team_a_id'], 'name' => 'Team A', 'short_name' => 'TMA'];

    $teamBStmt = $pdo->prepare("SELECT id, name, short_name, icon FROM teams WHERE id = ?");
    $teamBStmt->execute([(int)$m['team_b_id']]);
    $teamB = $teamBStmt->fetch(PDO::FETCH_ASSOC) ?: ['id' => $m['team_b_id'], 'name' => 'Team B', 'short_name' => 'TMB'];

    // Fetch Tournament Name
    $tournName = 'Friendly Match';
    if (!empty($m['tournament_id'])) {
        $tStmt = $pdo->prepare("SELECT name FROM tournaments WHERE id = ?");
        $tStmt->execute([(int)$m['tournament_id']]);
        $tRow = $tStmt->fetch(PDO::FETCH_ASSOC);
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
    $inningsList = $innStmt->fetchAll(PDO::FETCH_ASSOC);

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

    // Determine Scores specifically mapped to Team A and Team B
    $scoreA = null;
    $scoreB = null;
    foreach ($scores as $sc) {
        if ($sc['batting_team_id'] === (int)$teamA['id']) {
            $scoreA = $sc;
        } else if ($sc['batting_team_id'] === (int)$teamB['id']) {
            $scoreB = $sc;
        }
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
        'id'              => $matchId,
        'tournament_id'   => $m['tournament_id'] ? (int)$m['tournament_id'] : null,
        'tournament_name' => $tournName,
        'status'          => $m['status'], // 'scheduled', 'live', 'completed'
        'overs_limit'     => (int)$m['overs_limit'],
        'team_a'          => $teamA,
        'team_b'          => $teamB,
        'score_team_a'    => $scoreA ? "{$scoreA['runs']}/{$scoreA['wickets']} ({$scoreA['overs']} ov)" : null,
        'score_team_b'    => $scoreB ? "{$scoreB['runs']}/{$scoreB['wickets']} ({$scoreB['overs']} ov)" : null,
        'scores'          => $scores,
        'toss_winner_id'  => $m['toss_winner_team_id'] ? (int)$m['toss_winner_team_id'] : null,
        'toss_decision'   => $m['toss_decision'] ?? null,
        'winner_id'       => $m['winner_team_id'] ? (int)$m['winner_team_id'] : null,
        'winner_name'     => $winnerName,
        'result_type'     => $m['result_type'] ?? null,
        'state'           => $m['state'] ?? 'Tamil Nadu',
        'district'        => $m['district'] ?? 'Coimbatore',
        'city_area'       => $m['city_area'] ?? null,
        'venue_name'      => $m['venue_name'] ?? null,
        'match_code'      => $m['match_code'] ?? null,
        'scores'          => $scores,
        'created_at'      => $m['created_at'] ?? null,
    ];
}

// Function to build query with filter
function getMatchesByFilter(PDO $pdo, string $statusClause, string $filter, string $district, string $state, array $myTeamIds, string $cleanPhone = '', int $limit = 10): array {
    $where = [$statusClause];
    $params = [];

    if ($filter === 'my_matches') {
        $myConds = [];
        if (!empty($myTeamIds)) {
            $inPlaceholders = implode(',', array_fill(0, count($myTeamIds), '?'));
            $myConds[] = "team_a_id IN ($inPlaceholders) OR team_b_id IN ($inPlaceholders)";
            $params = array_merge($params, $myTeamIds, $myTeamIds);
        }
        if (!empty($cleanPhone)) {
            $myConds[] = "id IN (SELECT match_id FROM match_playing_xi WHERE player_id IN (SELECT id FROM players WHERE mobile LIKE ?))";
            $params[] = "%$cleanPhone%";
        }
        if (!empty($myConds)) {
            $where[] = "(" . implode(' OR ', $myConds) . ")";
        } else {
            // No teams or registered phone yet for this user
            return [];
        }
    } else if ($filter === 'district' && !empty($district)) {
        $where[] = "(district = ? OR (tournament_id IN (SELECT id FROM tournaments WHERE district = ?)))";
        $params[] = $district;
        $params[] = $district;
    }

    $whereSql = implode(' AND ', $where);
    $orderSql = (strpos($statusClause, 'completed') !== false) ? 'ORDER BY id DESC' : 'ORDER BY id DESC';
    $stmt = $pdo->prepare("SELECT * FROM matches WHERE $whereSql $orderSql LIMIT $limit");
    $stmt->execute($params);
    $raw = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $out = [];
    foreach ($raw as $m) {
        $out[] = formatMatchSummary($pdo, $m);
    }
    return $out;
}

// Auto-finalize finished or stale live matches (>6 hours or 2nd innings finished)
try {
    $staleLive = $pdo->query("
        SELECT m.id, m.team_a_id, m.team_b_id, m.overs_limit,
               i1.id as i1_id, i1.batting_team_id as i1_bat, i1.total_runs as i1_runs,
               i2.id as i2_id, i2.batting_team_id as i2_bat, i2.total_runs as i2_runs, i2.target, i2.total_legal_balls as i2_balls, i2.completed as i2_comp,
               TIMESTAMPDIFF(HOUR, m.created_at, NOW()) as hours_old
        FROM matches m
        LEFT JOIN innings i1 ON i1.match_id = m.id AND i1.innings_no = 1
        LEFT JOIN innings i2 ON i2.match_id = m.id AND i2.innings_no = 2
        WHERE m.status IN ('live', 'in_progress')
    ")->fetchAll(PDO::FETCH_ASSOC);

    foreach ($staleLive as $lm) {
        $mid = (int)$lm['id'];
        $oversLimitBalls = (int)$lm['overs_limit'] * 6;
        $i2Target = (int)($lm['target'] ?? 0);
        $i2Runs = (int)($lm['i2_runs'] ?? 0);
        $i2Balls = (int)($lm['i2_balls'] ?? 0);
        $i1Bat = (int)($lm['i1_bat'] ?? 0);
        $i2Bat = (int)($lm['i2_bat'] ?? 0);
        $hoursOld = (int)($lm['hours_old'] ?? 0);

        $isDone = false;
        $winnerId = null;
        $resType = null;

        if ($lm['i2_id']) {
            if ($i2Target > 0 && $i2Runs >= $i2Target) {
                $isDone = true;
                $winnerId = $i2Bat;
                $resType = ($winnerId === (int)$lm['team_a_id']) ? 'A' : 'B';
            } else if ($lm['i2_comp'] == 1 || ($oversLimitBalls > 0 && $i2Balls >= $oversLimitBalls)) {
                $isDone = true;
                if ($i2Runs >= $i2Target && $i2Target > 0) {
                    $winnerId = $i2Bat;
                    $resType = ($winnerId === (int)$lm['team_a_id']) ? 'A' : 'B';
                } else if ($i2Target > 0 && $i2Runs === ($i2Target - 1)) {
                    $winnerId = null;
                    $resType = 'tie';
                } else {
                    $winnerId = $i1Bat;
                    $resType = ($winnerId === (int)$lm['team_a_id']) ? 'A' : 'B';
                }
            }
        }

        // If match is older than 6 hours and inactive, mark completed
        if (!$isDone && $hoursOld >= 6) {
            $isDone = true;
            if ($lm['i2_id'] && $i2Target > 0) {
                if ($i2Runs >= $i2Target) {
                    $winnerId = $i2Bat;
                    $resType = ($winnerId === (int)$lm['team_a_id']) ? 'A' : 'B';
                } else {
                    $winnerId = $i1Bat;
                    $resType = ($winnerId === (int)$lm['team_a_id']) ? 'A' : 'B';
                }
            }
        }

        if ($isDone) {
            $pdo->prepare("UPDATE matches SET status = 'completed', winner_team_id = ?, result_type = ? WHERE id = ?")->execute([$winnerId, $resType, $mid]);
            if ($lm['i2_id']) {
                $pdo->prepare("UPDATE innings SET completed = 1 WHERE id = ?")->execute([(int)$lm['i2_id']]);
            }
            if ($lm['i1_id']) {
                $pdo->prepare("UPDATE innings SET completed = 1 WHERE id = ?")->execute([(int)$lm['i1_id']]);
            }
        }
    }
} catch (Throwable $e) {}

// 1. Live Matches
$liveMatches = getMatchesByFilter($pdo, "status IN ('live', 'in_progress')", $filter, $district, $state, $myTeamIds, $cleanPhone, 10);

// Fallback: If "my_matches" filter returned empty, also provide general district live matches as recommendation
$districtLiveMatches = [];
if ($filter === 'my_matches' && empty($liveMatches) && !empty($district)) {
    $districtLiveMatches = getMatchesByFilter($pdo, "status IN ('live', 'in_progress')", 'district', $district, $state, [], '', 5);
}

// 2. Upcoming Matches
$upcomingMatches = getMatchesByFilter($pdo, "status IN ('scheduled', 'upcoming')", $filter, $district, $state, $myTeamIds, $cleanPhone, 10);

// 3. Recent Results
$recentResults = getMatchesByFilter($pdo, "status IN ('completed', 'finished')", $filter, $district, $state, $myTeamIds, $cleanPhone, 10);

// 4. Active Tournaments filtered by District/State
$tournParams = [];
$tournWhere = "1=1";
if ($filter === 'district' && !empty($district)) {
    $tournWhere = "(district = ? OR state = ?)";
    $tournParams[] = $district;
    $tournParams[] = $state;
}
$tournStmt = $pdo->prepare("
    SELECT t.*,
           (SELECT COUNT(*) FROM teams tm WHERE tm.tournament_id = t.id) as total_teams,
           (SELECT COUNT(*) FROM matches m WHERE m.tournament_id = t.id) as total_matches
    FROM tournaments t
    WHERE $tournWhere
    ORDER BY t.id DESC LIMIT 8
");
$tournStmt->execute($tournParams);
$tournaments = $tournStmt->fetchAll(PDO::FETCH_ASSOC);

// If district had no tournaments, fetch global tournaments
if (empty($tournaments)) {
    $tournStmt2 = $pdo->query("
        SELECT t.*,
               (SELECT COUNT(*) FROM teams tm WHERE tm.tournament_id = t.id) as total_teams,
               (SELECT COUNT(*) FROM matches m WHERE m.tournament_id = t.id) as total_matches
        FROM tournaments t
        ORDER BY t.id DESC LIMIT 6
    ");
    $tournaments = $tournStmt2->fetchAll(PDO::FETCH_ASSOC);
}

// 5. App Banners (Dynamic)
$banners = [
    [
        'id'          => 1,
        'title'       => 'SB CricScore ' . (!empty($district) ? $district : 'Tamil Nadu') . ' League',
        'subtitle'    => 'Host turf matches & live stream ball-by-ball!',
        'button_text' => 'Explore Tournaments',
        'image_url'   => 'assets/banner1.png'
    ],
    [
        'id'          => 2,
        'title'       => 'Gully & Turf Live Scorer',
        'subtitle'    => 'Scan QR code & start 3D Coin Toss immediately!',
        'button_text' => 'Create Match',
        'image_url'   => 'assets/banner2.png'
    ]
];

echo json_encode([
    'success'               => true,
    'filter'                => $filter,
    'selected_district'     => $district,
    'selected_state'        => $state,
    'my_team_ids_count'     => count($myTeamIds),
    'user'                  => $currentUser ? [
        'id'       => (int)$currentUser['id'],
        'name'     => $currentUser['name'],
        'city'     => $currentUser['city'] ?? $district,
        'district' => $currentUser['district'] ?? $district,
        'state'    => $currentUser['state'] ?? $state,
    ] : null,
    'live_matches'          => $liveMatches,
    'district_live_fallback'=> $districtLiveMatches,
    'upcoming_matches'      => $upcomingMatches,
    'recent_results'        => $recentResults,
    'tournaments'           => $tournaments,
    'banners'               => $banners
]);
