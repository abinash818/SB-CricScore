<?php
// api/match_create.php
// Creates a new match fixture
// POST (JSON or Form Data)

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { 
    http_response_code(200); 
    exit; 
}

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$rawBody = file_get_contents('php://input');
$input = json_decode($rawBody, true);
if (!is_array($input)) {
    $input = $_POST;
}

$tid       = (int)($input['tournament_id'] ?? 0);
$team_a    = (int)($input['team_a_id'] ?? 0);
$team_b    = (int)($input['team_b_id'] ?? 0);
$bat_first = (int)($input['batting_first_team_id'] ?? 0);
$overs     = (int)($input['overs_limit'] ?? 20);
$wickets   = (int)($input['wickets_limit'] ?? 10);
$is_final  = (int)($input['is_final'] ?? 0);
$match_date = trim($input['match_date'] ?? '');
$match_time = trim($input['match_time'] ?? '');
$stage      = trim($input['stage'] ?? ($is_final ? 'Final' : 'League'));

if ($team_a <= 0 || $team_b <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Team A and Team B are required']);
    exit;
}

if ($team_a === $team_b) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Team A and Team B cannot be the same team']);
    exit;
}

// Function to fetch available columns for a table safely
function get_table_columns_safe(PDO $pdo, string $table): array {
    $cols = [];
    try {
        $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
        if ($driver === 'sqlite') {
            $st = $pdo->query("PRAGMA table_info($table)");
            while ($r = $st->fetch(PDO::FETCH_ASSOC)) {
                $cols[strtolower($r['name'])] = true;
            }
        } else {
            $st = $pdo->query("SHOW COLUMNS FROM $table");
            while ($r = $st->fetch(PDO::FETCH_ASSOC)) {
                $cols[strtolower($r['Field'])] = true;
            }
        }
    } catch (Throwable $e) {}
    return $cols;
}

try {
    // Check and auto-migrate missing columns if necessary
    $existingCols = get_table_columns_safe($pdo, 'matches');
    $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

    if (!isset($existingCols['match_date'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN match_date TEXT DEFAULT NULL" : "ALTER TABLE matches ADD COLUMN match_date VARCHAR(30) DEFAULT NULL");
            $existingCols['match_date'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['match_time'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN match_time TEXT DEFAULT NULL" : "ALTER TABLE matches ADD COLUMN match_time VARCHAR(30) DEFAULT NULL");
            $existingCols['match_time'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['stage'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN stage TEXT DEFAULT 'League'" : "ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League'");
            $existingCols['stage'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['wickets_limit'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN wickets_limit INTEGER DEFAULT 10" : "ALTER TABLE matches ADD COLUMN wickets_limit INT DEFAULT 10");
            $existingCols['wickets_limit'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['is_final'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN is_final INTEGER DEFAULT 0" : "ALTER TABLE matches ADD COLUMN is_final TINYINT(1) DEFAULT 0");
            $existingCols['is_final'] = true;
        } catch (Throwable $e) {}
    }

    $venue_name = trim($input['venue_name'] ?? ($input['ground_name'] ?? ''));
    $ball_type  = trim($input['ball_type'] ?? 'tennis_light');
    $youtube_url= trim($input['youtube_live_url'] ?? '');
    $invite_st  = trim($input['invite_status'] ?? ($team_b > 0 ? 'accepted' : 'pending'));

    // Generate unique 6-character match_code
    $match_code = 'SB' . strtoupper(substr(md5(uniqid((string)mt_rand(), true)), 0, 4));

    if (!isset($existingCols['match_code'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN match_code TEXT DEFAULT NULL" : "ALTER TABLE matches ADD COLUMN match_code VARCHAR(30) DEFAULT NULL");
            $existingCols['match_code'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['venue_name'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN venue_name TEXT DEFAULT NULL" : "ALTER TABLE matches ADD COLUMN venue_name VARCHAR(150) DEFAULT NULL");
            $existingCols['venue_name'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['ball_type'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN ball_type TEXT DEFAULT 'tennis_light'" : "ALTER TABLE matches ADD COLUMN ball_type VARCHAR(30) DEFAULT 'tennis_light'");
            $existingCols['ball_type'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['invite_status'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN invite_status TEXT DEFAULT 'accepted'" : "ALTER TABLE matches ADD COLUMN invite_status VARCHAR(30) DEFAULT 'accepted'");
            $existingCols['invite_status'] = true;
        } catch (Throwable $e) {}
    }
    if (!isset($existingCols['youtube_live_url'])) {
        try {
            $pdo->exec($driver === 'sqlite' ? "ALTER TABLE matches ADD COLUMN youtube_live_url TEXT DEFAULT NULL" : "ALTER TABLE matches ADD COLUMN youtube_live_url VARCHAR(255) DEFAULT NULL");
            $existingCols['youtube_live_url'] = true;
        } catch (Throwable $e) {}
    }

    $pdo->beginTransaction();
    
    $status = ($bat_first > 0) ? 'live' : 'scheduled';
    $toss_winner = ($bat_first > 0) ? $bat_first : null;
    $toss_dec = ($bat_first > 0) ? 'bat' : null;

    // Dynamically build insert array only for columns that exist in the database table
    $insertData = [
        'tournament_id'       => ($tid > 0 ? $tid : null),
        'team_a_id'           => $team_a,
        'team_b_id'           => $team_b,
        'toss_winner_team_id' => $toss_winner,
        'toss_decision'       => $toss_dec,
        'overs_limit'         => $overs,
        'wickets_limit'       => $wickets,
        'is_final'            => $is_final,
        'match_date'          => ($match_date ?: null),
        'match_time'          => ($match_time ?: null),
        'stage'               => ($stage ?: 'League'),
        'status'              => $status,
        'match_code'          => $match_code,
        'venue_name'          => ($venue_name ?: null),
        'ball_type'           => ($ball_type ?: 'tennis_light'),
        'invite_status'       => $invite_st,
        'youtube_live_url'    => ($youtube_url ?: null),
    ];

    $fields = [];
    $placeholders = [];
    $values = [];

    foreach ($insertData as $col => $val) {
        if (isset($existingCols[$col]) || empty($existingCols)) {
            $fields[] = $col;
            $placeholders[] = '?';
            $values[] = $val;
        }
    }

    $sql = "INSERT INTO matches (" . implode(', ', $fields) . ") VALUES (" . implode(', ', $placeholders) . ")";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($values);
    $match_id = (int)$pdo->lastInsertId();

    if ($bat_first > 0) {
        $bowling = ($bat_first == $team_a ? $team_b : $team_a);
        // Create Innings 1
        $i1 = $pdo->prepare("INSERT INTO innings (match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES (?, 1, ?, ?, 0)");
        $i1->execute([$match_id, $bat_first, $bowling]);

        // Create Innings 2
        $i2 = $pdo->prepare("INSERT INTO innings (match_id, innings_no, batting_team_id, bowling_team_id, completed) VALUES (?, 2, ?, ?, 0)");
        $i2->execute([$match_id, $bowling, $bat_first]);
    }

    $pdo->commit();

    $shareLink = "https://sbastro.com/tournament/pages/match.php?match_id={$match_id}&code={$match_code}";
    $qrPayload = json_encode([
        'type'       => 'sbcric_match_invite',
        'match_id'   => $match_id,
        'match_code' => $match_code,
        'team_a_id'  => $team_a,
        'venue'      => $venue_name,
        'overs'      => $overs,
        'ball_type'  => $ball_type,
    ]);

    echo json_encode([
        'success'      => true,
        'ok'           => true,
        'match_id'     => $match_id,
        'match_code'   => $match_code,
        'share_link'   => $shareLink,
        'qr_payload'   => $qrPayload,
        'venue_name'   => $venue_name,
        'ball_type'    => $ball_type,
        'message'      => 'Match created successfully'
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}