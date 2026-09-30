<?php
// api/search_ops.php
// Universal Search & Discovery Engine API
// GET /api/search_ops.php?q=query&type=all|players|teams|tournaments|matches

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$query = trim($_GET['q'] ?? '');
$type  = trim($_GET['type'] ?? 'all');

if (empty($query) || strlen($query) < 2) {
    echo json_encode([
        'success'     => true,
        'query'       => $query,
        'players'     => [],
        'teams'       => [],
        'tournaments' => [],
        'matches'     => []
    ]);
    exit;
}

$like = '%' . strtolower($query) . '%';

$results = [
    'success'     => true,
    'query'       => $query,
    'players'     => [],
    'teams'       => [],
    'tournaments' => [],
    'matches'     => []
];

try {
    // 1. PLAYERS SEARCH (Name or Phone number)
    if ($type === 'all' || $type === 'players') {
        $pList = [];
        $seenMobiles = [];
        $seenNames = [];

        // Digits for mobile
        $digitsOnly = preg_replace('/\D+/', '', $query);
        $last10 = (strlen($digitsOnly) >= 10) ? substr($digitsOnly, -10) : $digitsOnly;
        $likeMobile = !empty($last10) ? '%' . $last10 . '%' : $like;

        // App users
        try {
            $uStmt = $pdo->prepare("
                SELECT id, name, mobile, role, jersey_number, profile_pic, batting_style, bowling_style, city
                FROM app_users
                WHERE LOWER(name) LIKE ? OR mobile LIKE ?
                ORDER BY id DESC LIMIT 15
            ");
            $uStmt->execute([$like, $likeMobile]);
            $uRows = $uStmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($uRows as $u) {
                $mob = trim($u['mobile'] ?? '');
                $nm = trim($u['name'] ?? '');
                if (!empty($mob)) $seenMobiles[$mob] = true;
                if (!empty($nm)) $seenNames[strtolower($nm)] = true;

                $pList[] = [
                    'id'            => (int)$u['id'],
                    'name'          => !empty($u['name']) ? $u['name'] : 'User (' . $mob . ')',
                    'mobile'        => $mob,
                    'role'          => !empty($u['role']) ? $u['role'] : 'All-Rounder',
                    'jersey_number' => $u['jersey_number'] ?? '',
                    'profile_pic'   => $u['profile_pic'] ?? null,
                    'batting_style' => $u['batting_style'] ?? 'Right Hand Bat',
                    'bowling_style' => $u['bowling_style'] ?? 'Right Arm Medium',
                    'team_name'     => 'Registered User ⭐',
                ];
            }
        } catch (\Throwable $e) {}

        // Tournament Players
        try {
            $pStmt = $pdo->prepare("
                SELECT p.id, p.name, p.role, p.jersey_number, p.profile_pic, p.mobile, p.batting_style, p.bowling_style,
                       t.id as team_id, t.name as team_name
                FROM players p
                LEFT JOIN teams t ON t.id = p.team_id
                WHERE LOWER(p.name) LIKE ? OR p.mobile LIKE ?
                ORDER BY p.name ASC LIMIT 15
            ");
            $pStmt->execute([$like, $likeMobile]);
            $tRows = $pStmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($tRows as $p) {
                $mob = trim($p['mobile'] ?? '');
                $nm = trim($p['name'] ?? '');
                if (!empty($mob) && isset($seenMobiles[$mob])) continue;
                if (empty($mob) && !empty($nm) && isset($seenNames[strtolower($nm)])) continue;
                $pList[] = $p;
            }
        } catch (\Throwable $e) {}

        $results['players'] = $pList;
    }


    // 2. TEAMS SEARCH
    if ($type === 'all' || $type === 'teams') {
        $tStmt = $pdo->prepare("
            SELECT t.id, t.name, t.short_name, t.icon, t.tournament_id,
                   (SELECT COUNT(*) FROM players p WHERE p.team_id = t.id) as player_count,
                   tour.name as tournament_name
            FROM teams t
            LEFT JOIN tournaments tour ON tour.id = t.tournament_id
            WHERE LOWER(t.name) LIKE ? OR LOWER(t.short_name) LIKE ?
            ORDER BY t.name ASC LIMIT 10
        ");
        $tStmt->execute([$like, $like]);
        $results['teams'] = $tStmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // 3. TOURNAMENTS SEARCH
    if ($type === 'all' || $type === 'tournaments') {
        $tourStmt = $pdo->prepare("
            SELECT tour.id, tour.name, tour.type, tour.default_overs,
                   (SELECT COUNT(*) FROM teams tm WHERE tm.tournament_id = tour.id) as team_count,
                   (SELECT COUNT(*) FROM matches m WHERE m.tournament_id = tour.id) as match_count
            FROM tournaments tour
            WHERE LOWER(tour.name) LIKE ?
            ORDER BY tour.id DESC LIMIT 10
        ");
        $tourStmt->execute([$like]);
        $results['tournaments'] = $tourStmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // 4. MATCHES SEARCH
    if ($type === 'all' || $type === 'matches') {
        $mStmt = $pdo->prepare("
            SELECT m.id, m.status, m.overs_limit, m.tournament_id,
                   ta.name as team_a_name, ta.short_name as team_a_short,
                   tb.name as team_b_name, tb.short_name as team_b_short,
                   tw.name as winner_name, tour.name as tournament_name
            FROM matches m
            JOIN teams ta ON m.team_a_id = ta.id
            JOIN teams tb ON m.team_b_id = tb.id
            LEFT JOIN teams tw ON m.winner_team_id = tw.id
            LEFT JOIN tournaments tour ON tour.id = m.tournament_id
            WHERE LOWER(ta.name) LIKE ? OR LOWER(tb.name) LIKE ? OR LOWER(tour.name) LIKE ?
            ORDER BY m.id DESC LIMIT 10
        ");
        $mStmt->execute([$like, $like, $like]);
        $results['matches'] = $mStmt->fetchAll(PDO::FETCH_ASSOC);
    }

    echo json_encode($results);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
