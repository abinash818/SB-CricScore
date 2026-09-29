<?php
// api/share_ops.php
// Social Sharing & Match Scorecard Export API
// GET /api/share_ops.php?action=match_share&match_id=X
// GET /api/share_ops.php?action=tournament_share&tournament_id=X

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';

$action = $_GET['action'] ?? 'match_share';

// ── 1. MATCH SHARE SUMMARY ───────────────────────────────────────────────────
if ($action === 'match_share') {
    $matchId = (int)($_GET['match_id'] ?? 0);
    if ($matchId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'match_id is required']);
        exit;
    }

    $mStmt = $pdo->prepare("
        SELECT m.*, 
               ta.name as team_a_name, ta.short_name as team_a_short,
               tb.name as team_b_name, tb.short_name as team_b_short,
               tw.name as winner_name, tour.name as tournament_name
        FROM matches m
        JOIN teams ta ON m.team_a_id = ta.id
        JOIN teams tb ON m.team_b_id = tb.id
        LEFT JOIN teams tw ON m.winner_team_id = tw.id
        LEFT JOIN tournaments tour ON tour.id = m.tournament_id
        WHERE m.id = ?
    ");
    $mStmt->execute([$matchId]);
    $m = $mStmt->fetch(PDO::FETCH_ASSOC);

    if (!$m) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Match not found']);
        exit;
    }

    $tournName = $m['tournament_name'] ?? 'Friendly Match';
    $teamA = $m['team_a_name'];
    $teamB = $m['team_b_name'];
    $status = strtoupper($m['status']);

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
    $inns = $innStmt->fetchAll(PDO::FETCH_ASSOC);

    $scoreLines = [];
    foreach ($inns as $inn) {
        $legalBalls = (int)($inn['legal_balls'] ?? 0);
        $overs = floor($legalBalls / 6) + (($legalBalls % 6) / 10);
        $tName = ($inn['batting_team_id'] == $m['team_a_id']) ? $teamA : $teamB;
        $runs = (int)($inn['runs'] ?? 0);
        $wickets = (int)($inn['wickets'] ?? 0);
        $scoreLines[] = "$tName: $runs/$wickets ($overs ov)";
    }

    $scoreString = !empty($scoreLines) ? implode("\n", $scoreLines) : "Match Scheduled";
    $resultString = "";
    if ($m['status'] === 'completed' && !empty($m['winner_name'])) {
        $resultString = "\n🏆 " . $m['winner_name'] . " won!";
    } else if ($m['status'] === 'live') {
        $resultString = "\n🔴 Match LIVE Now!";
    }

    $webUrl = "https://sbastro.com/tournament/pages/match.php?id=" . $matchId;
    $shareText = "🏏 $tournName\n$teamA vs $teamB\n\n$scoreString$resultString\n\nView Full Scorecard on SB CricScore:\n$webUrl";

    echo json_encode([
        'success'      => true,
        'match_id'     => $matchId,
        'share_text'   => $shareText,
        'whatsapp_url' => "https://api.whatsapp.com/send?text=" . urlencode($shareText),
        'web_url'      => $webUrl
    ]);
    exit;
}

// ── 2. TOURNAMENT SHARE SUMMARY ──────────────────────────────────────────────
if ($action === 'tournament_share') {
    $tid = (int)($_GET['tournament_id'] ?? 0);
    if ($tid <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'tournament_id is required']);
        exit;
    }

    $tStmt = $pdo->prepare("SELECT * FROM tournaments WHERE id = ?");
    $tStmt->execute([$tid]);
    $t = $tStmt->fetch(PDO::FETCH_ASSOC);

    if (!$t) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Tournament not found']);
        exit;
    }

    $webUrl = "https://sbastro.com/tournament/pages/tournament.php?id=" . $tid;
    $shareText = "🏆 Follow " . $t['name'] . " Live Standings, Fixtures & Stats on SB CricScore!\n\n$webUrl";

    echo json_encode([
        'success'      => true,
        'share_text'   => $shareText,
        'whatsapp_url' => "https://api.whatsapp.com/send?text=" . urlencode($shareText),
        'web_url'      => $webUrl
    ]);
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);
