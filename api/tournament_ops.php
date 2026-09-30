<?php
// api/tournament_ops.php
// Tournament Management API for Mobile App & Web
// GET  /api/tournament_ops.php?action=list
// GET  /api/tournament_ops.php?action=get&tournament_id=X
// POST /api/tournament_ops.php?action=create
// POST /api/tournament_ops.php?action=generate_fixtures

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/_helpers.php';
require_once __DIR__ . '/app_auth.php';

$action = $_GET['action'] ?? ($_POST['action'] ?? 'list');

// ── 1. LIST TOURNAMENTS ──────────────────────────────────────────────────────
if ($action === 'list') {
    $search = trim($_GET['q'] ?? '');
    $where = [];
    $params = [];

    if (!empty($search)) {
        $where[] = "LOWER(name) LIKE ?";
        $params[] = '%' . strtolower($search) . '%';
    }

    $sql = "SELECT t.*, 
                   (SELECT COUNT(*) FROM teams tm WHERE tm.tournament_id = t.id) as team_count,
                   (SELECT COUNT(*) FROM matches m WHERE m.tournament_id = t.id) as match_count
            FROM tournaments t";
    if (!empty($where)) {
        $sql .= " WHERE " . implode(' AND ', $where);
    }
    $sql .= " ORDER BY t.id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $tournaments = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(['success' => true, 'tournaments' => $tournaments]);
    exit;
}

// ── 2. GET TOURNAMENT DETAILS (Hub Data) ────────────────────────────────────
if ($action === 'get') {
    try {
        $tid = (int)($_GET['tournament_id'] ?? 0);
        if ($tid <= 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'tournament_id is required']);
            exit;
        }

        $tStmt = $pdo->prepare("SELECT * FROM tournaments WHERE id = ?");
        $tStmt->execute([$tid]);
        $tournament = $tStmt->fetch(PDO::FETCH_ASSOC);

        if (!$tournament) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Tournament not found']);
            exit;
        }

        // Teams
        $teamsStmt = $pdo->prepare("SELECT t.*, (SELECT COUNT(*) FROM players p WHERE p.team_id = t.id) as player_count FROM teams t WHERE t.tournament_id = ? ORDER BY t.name ASC");
        $teamsStmt->execute([$tid]);
        $teams = $teamsStmt->fetchAll(PDO::FETCH_ASSOC);

        // Fixtures / Matches
        $matchesStmt = $pdo->prepare("
            SELECT m.*, 
                   ta.name as team_a_name, ta.short_name as team_a_short,
                   tb.name as team_b_name, tb.short_name as team_b_short,
                   tw.name as winner_name
            FROM matches m
            JOIN teams ta ON m.team_a_id = ta.id
            JOIN teams tb ON m.team_b_id = tb.id
            LEFT JOIN teams tw ON m.winner_team_id = tw.id
            WHERE m.tournament_id = ?
            ORDER BY m.id DESC
        ");
        $matchesStmt->execute([$tid]);
        $matches = $matchesStmt->fetchAll(PDO::FETCH_ASSOC);

        // Points Table Calculation
        $winPts  = (int)($tournament['win_points'] ?? 2);
        $tiePts  = (int)($tournament['tie_points'] ?? 1);
        $nrPts   = (int)($tournament['nr_points'] ?? 1);
        $lossPts = (int)($tournament['loss_points'] ?? 0);

        $rows = [];
        foreach ($teams as $tm) {
            $rows[(int)$tm['id']] = [
                'team_id'       => (int)$tm['id'],
                'team'          => $tm['name'],
                'short_name'    => $tm['short_name'] ?? 'TM',
                'icon'          => $tm['icon'] ?? 'shield',
                'group_name'    => !empty($tm['group_name']) ? $tm['group_name'] : null,
                'P' => 0, 'W' => 0, 'L' => 0, 'T' => 0, 'NR' => 0, 'Pts' => 0,
                'runs_for' => 0, 'overs_for' => 0.0, 'runs_against' => 0, 'overs_against' => 0.0,
                'NRR' => 0.0
            ];
        }

        $completedMatches = array_filter($matches, fn($m) => $m['status'] === 'completed');
        foreach ($completedMatches as $m) {
            $a = (int)$m['team_a_id'];
            $b = (int)$m['team_b_id'];
            if (!isset($rows[$a]) || !isset($rows[$b])) continue;

            $rows[$a]['P']++; $rows[$b]['P']++;
            $winnerId = (int)($m['winner_team_id'] ?? 0);
            $rt = $m['result_type'] ?? '';
            if ($winnerId === $a) {
                $rows[$a]['W']++; $rows[$b]['L']++;
                $rows[$a]['Pts'] += $winPts;
                $rows[$b]['Pts'] += $lossPts;
            } else if ($winnerId === $b) {
                $rows[$b]['W']++; $rows[$a]['L']++;
                $rows[$b]['Pts'] += $winPts;
                $rows[$a]['Pts'] += $lossPts;
            } else if ($rt === 'tie') {
                $rows[$a]['T']++; $rows[$b]['T']++;
                $rows[$a]['Pts'] += $tiePts;
                $rows[$b]['Pts'] += $tiePts;
            } else if ($rt === 'nr') {
                $rows[$a]['NR']++; $rows[$b]['NR']++;
                $rows[$a]['Pts'] += $nrPts;
                $rows[$b]['Pts'] += $nrPts;
            }
        }

        $pointsTable = array_values($rows);
        usort($pointsTable, function($x, $y) {
            if ($x['Pts'] !== $y['Pts']) return $y['Pts'] <=> $x['Pts'];
            if ($x['W'] !== $y['W']) return $y['W'] <=> $x['W'];
            return strcmp($x['team'], $y['team']);
        });

        $shareLink = "https://sbastro.com/tournament/pages/tournament.php?tour_id={$tid}&register=1";
        $qrPayload = "sbcric_tourn:{$tid}";

        echo json_encode([
            'success'      => true,
            'tournament'   => $tournament,
            'teams'        => $teams,
            'matches'      => $matches,
            'points_table' => $pointsTable,
            'share_link'   => $shareLink,
            'qr_payload'   => $qrPayload,
        ]);
        exit;
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => $e->getMessage()]);
        exit;
    }
}

// ── 3. CREATE TOURNAMENT ─────────────────────────────────────────────────────
if ($action === 'create') {
    try {
        $input      = json_decode(file_get_contents('php://input'), true) ?? $_POST;
        $name       = trim($input['name'] ?? '');
        $type       = trim($input['type'] ?? 'round_robin');
        $winPts     = (int)($input['win_points'] ?? 2);
        $tiePts     = (int)($input['tie_points'] ?? 1);
        $nrPts      = (int)($input['nr_points'] ?? 1);
        $lossPts    = (int)($input['loss_points'] ?? 0);
        $defOvers   = (int)($input['default_overs'] ?? 20);
        $defWickets = (int)($input['default_wickets'] ?? 10);
        $teamNames  = $input['teams'] ?? [];

        if (empty($name)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Tournament name is required']);
            exit;
        }

        $st = $pdo->prepare("
            INSERT INTO tournaments (name, type, win_points, tie_points, nr_points, loss_points, default_overs, default_wickets)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $st->execute([$name, $type, $winPts, $tiePts, $nrPts, $lossPts, $defOvers, $defWickets]);
        $tid = (int)$pdo->lastInsertId();

        // Add optional initial teams
        $createdTeams = 0;
        if (is_array($teamNames) && !empty($teamNames)) {
            $insTeam = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
            foreach ($teamNames as $tName) {
                $tName = trim((string)$tName);
                if (empty($tName)) continue;
                $words = explode(' ', $tName);
                $short = strtoupper(substr($tName, 0, 3));
                if (count($words) >= 2) {
                    $short = strtoupper(substr($words[0], 0, 1) . substr($words[1], 0, 1));
                }
                try {
                    $insTeam->execute([$tid, $tName, $short, 'shield']);
                    $createdTeams++;
                } catch (Throwable $te) {}
            }
        }

        echo json_encode([
            'success'       => true,
            'message'       => 'Tournament created successfully',
            'tournament_id' => $tid,
            'teams_added'   => $createdTeams
        ]);
        exit;
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
        exit;
    }
}

// ── 4. GENERATE FIXTURES ─────────────────────────────────────────────────────
if ($action === 'generate_fixtures') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $tid   = (int)($input['tournament_id'] ?? 0);
    $overs = (int)($input['overs_limit'] ?? 20);
    $type  = $input['type'] ?? 'single'; // 'single', 'double', 'knockout'

    if ($tid <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'tournament_id is required']);
        exit;
    }

    $teamsStmt = $pdo->prepare("SELECT id, name FROM teams WHERE tournament_id = ? ORDER BY id ASC");
    $teamsStmt->execute([$tid]);
    $teams = $teamsStmt->fetchAll(PDO::FETCH_ASSOC);

    if (count($teams) < 2) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Add at least 2 teams to generate fixtures']);
        exit;
    }

    $created = 0;
    $insMatch = $pdo->prepare("INSERT INTO matches (tournament_id, team_a_id, team_b_id, overs_limit, status) VALUES (?, ?, ?, ?, 'scheduled')");

    if ($type === 'double') {
        for ($i = 0; $i < count($teams); $i++) {
            for ($j = 0; $j < count($teams); $j++) {
                if ($i === $j) continue;
                $insMatch->execute([$tid, $teams[$i]['id'], $teams[$j]['id'], $overs]);
                $created++;
            }
        }
    } else if ($type === 'knockout') {
        $ids = array_map(fn($x) => (int)$x['id'], $teams);
        $i = 0; $j = count($ids) - 1;
        while ($i < $j) {
            $insMatch->execute([$tid, $ids[$i], $ids[$j], $overs]);
            $created++;
            $i++; $j--;
        }
    } else {
        // Single Round Robin
        for ($i = 0; $i < count($teams); $i++) {
            for ($j = $i + 1; $j < count($teams); $j++) {
                $insMatch->execute([$tid, $teams[$i]['id'], $teams[$j]['id'], $overs]);
                $created++;
            }
        }
    }

    echo json_encode([
        'success' => true,
        'message' => "Generated {$created} match fixtures",
        'created' => $created
    ]);
    exit;
}

// ── 5. REGISTER TEAM TO TOURNAMENT VIA QR / LINK ────────────────────────────
if ($action === 'register_team') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $tid   = (int)($input['tournament_id'] ?? 0);
    $existingTeamId = (int)($input['team_id'] ?? 0);
    $teamName = trim($input['team_name'] ?? '');
    $captainName = trim($input['captain_name'] ?? '');
    $captainMobile = trim($input['captain_mobile'] ?? '');
    $playerNames = $input['player_names'] ?? [];

    if ($tid <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'tournament_id is required']);
        exit;
    }

    try {
        $tStmt = $pdo->prepare("SELECT * FROM tournaments WHERE id = ?");
        $tStmt->execute([$tid]);
        $tournament = $tStmt->fetch(PDO::FETCH_ASSOC);

        if (!$tournament) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Tournament not found']);
            exit;
        }

        $pdo->beginTransaction();

        $registeredTeamId = 0;

        // Option A: Clone an existing team into this tournament
        if ($existingTeamId > 0) {
            $exStmt = $pdo->prepare("SELECT * FROM teams WHERE id = ?");
            $exStmt->execute([$existingTeamId]);
            $exTeam = $exStmt->fetch(PDO::FETCH_ASSOC);

            if ($exTeam) {
                $teamName = $exTeam['name'];
                $shortName = $exTeam['short_name'];
                $icon = $exTeam['icon'] ?? 'shield';

                $insTeam = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
                $insTeam->execute([$tid, $teamName, $shortName, $icon]);
                $registeredTeamId = (int)$pdo->lastInsertId();

                // Clone Squad Players
                $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ?");
                $pStmt->execute([$existingTeamId]);
                $squad = $pStmt->fetchAll(PDO::FETCH_ASSOC);

                $insP = $pdo->prepare("INSERT INTO players (team_id, name, role, batting_style, bowling_style, jersey_number, is_captain, mobile) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                foreach ($squad as $p) {
                    $insP->execute([
                        $registeredTeamId,
                        $p['name'],
                        $p['role'] ?? 'BAT',
                        $p['batting_style'] ?? 'Right Hand Bat',
                        $p['bowling_style'] ?? 'Right Arm Medium',
                        $p['jersey_number'] ?? '',
                        (int)($p['is_captain'] ?? 0),
                        $p['mobile'] ?? ''
                    ]);
                }
            }
        }

        // Option B: Register new team with names
        if ($registeredTeamId <= 0) {
            if (empty($teamName)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Team Name is required']);
                exit;
            }

            $words = explode(' ', $teamName);
            $shortName = strtoupper(substr($teamName, 0, 3));
            if (count($words) >= 2) {
                $shortName = strtoupper(substr($words[0], 0, 1) . substr($words[1], 0, 1));
            }

            $insTeam = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, 'shield')");
            $insTeam->execute([$tid, $teamName, $shortName]);
            $registeredTeamId = (int)$pdo->lastInsertId();

            if (!empty($captainName)) {
                $insCap = $pdo->prepare("INSERT INTO players (team_id, name, role, is_captain, mobile) VALUES (?, ?, 'All-Rounder', 1, ?)");
                $insCap->execute([$registeredTeamId, $captainName, $captainMobile]);
            }

            if (!empty($playerNames) && is_array($playerNames)) {
                $insP = $pdo->prepare("INSERT INTO players (team_id, name, role) VALUES (?, ?, 'BAT')");
                foreach ($playerNames as $pname) {
                    $pname = trim($pname);
                    if (!empty($pname) && $pname !== $captainName) {
                        $insP->execute([$registeredTeamId, $pname]);
                    }
                }
            }
        }

        $pdo->commit();

        echo json_encode([
            'success'       => true,
            'message'       => "Team '{$teamName}' successfully registered for {$tournament['name']}! 🏆",
            'tournament_id' => $tid,
            'team_id'       => $registeredTeamId,
            'team_name'     => $teamName
        ]);
        exit;

    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Registration error: ' . $e->getMessage()]);
        exit;
    }
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);

