<?php
// api/analytics_get.php
// Returns match analytics data for Worm Chart, Manhattan, and Run Rate Graphs
// GET /api/analytics_get.php?match_id=X

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

// Fetch Innings
$innStmt = $pdo->prepare("SELECT * FROM innings WHERE match_id = ? ORDER BY innings_no ASC");
$innStmt->execute([$match_id]);
$inningsList = $innStmt->fetchAll();

$analytics = [];

foreach ($inningsList as $inn) {
    $innId = (int)$inn['id'];

    // Get team name
    $teamStmt = $pdo->prepare("SELECT id, name, short_name FROM teams WHERE id = ?");
    $teamStmt->execute([(int)$inn['batting_team_id']]);
    $team = $teamStmt->fetch() ?: ['name' => 'Team'];

    // Fetch ball events ordered by seq
    $ballsStmt = $pdo->prepare("SELECT * FROM ball_events WHERE innings_id = ? ORDER BY seq ASC");
    $ballsStmt->execute([$innId]);
    $balls = $ballsStmt->fetchAll();

    // Calculate Manhattan (runs per over), Worm (cumulative runs), and Run Rate per over
    $manhattan = [];
    $worm = [];
    $runRate = [];

    $cumulativeRuns = 0;
    $legalBallsCount = 0;
    $overRuns = 0;
    $overWickets = 0;
    $currentOver = 1;

    $totalDots = 0;
    $totalBoundaries = 0;

    foreach ($balls as $b) {
        $r = (int)$b['runs_bat'] + (int)$b['extras_runs'];
        $cumulativeRuns += $r;

        if ((int)$b['runs_bat'] == 0 && empty($b['extras_type'])) {
            $totalDots++;
        }
        if ((int)$b['runs_bat'] == 4 || (int)$b['runs_bat'] == 6) {
            $totalBoundaries++;
        }

        $overRuns += $r;
        if ((int)$b['is_wicket'] === 1) {
            $overWickets++;
        }

        if ((int)$b['is_legal'] === 1) {
            $legalBallsCount++;
            if ($legalBallsCount % 6 == 0) {
                // End of over
                $manhattan[] = [
                    'over'    => $currentOver,
                    'runs'    => $overRuns,
                    'wickets' => $overWickets,
                ];

                $worm[] = [
                    'over' => $currentOver,
                    'runs' => $cumulativeRuns,
                ];

                $crr = number_format($cumulativeRuns / $currentOver, 2);
                $runRate[] = [
                    'over' => $currentOver,
                    'crr'  => (float)$crr,
                ];

                $currentOver++;
                $overRuns = 0;
                $overWickets = 0;
            }
        }
    }

    // Include partial over if any
    if ($legalBallsCount % 6 != 0) {
        $manhattan[] = [
            'over'    => $currentOver,
            'runs'    => $overRuns,
            'wickets' => $overWickets,
        ];
        $worm[] = [
            'over' => $currentOver,
            'runs' => $cumulativeRuns,
        ];
        $oversDec = $legalBallsCount / 6;
        $crr = number_format($cumulativeRuns / $oversDec, 2);
        $runRate[] = [
            'over' => $currentOver,
            'crr'  => (float)$crr,
        ];
    }

    $dotPercentage = count($balls) > 0 ? round(($totalDots / count($balls)) * 100, 1) : 0;
    $boundaryPercentage = count($balls) > 0 ? round(($totalBoundaries / count($balls)) * 100, 1) : 0;

    $analytics[] = [
        'innings_no'          => (int)$inn['innings_no'],
        'batting_team'        => $team['name'],
        'total_runs'          => $cumulativeRuns,
        'dot_percentage'      => $dotPercentage,
        'boundary_percentage' => $boundaryPercentage,
        'manhattan'           => $manhattan,
        'worm'                => $worm,
        'run_rate'            => $runRate,
    ];
}

echo json_encode([
    'success'   => true,
    'match_id'  => $match_id,
    'analytics' => $analytics,
]);
