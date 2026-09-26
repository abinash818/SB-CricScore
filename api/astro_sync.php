<?php
// api/astro_sync.php - Multi-Source Player & Team Synchronizer
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';

header('Content-Type: application/json');

$action = $_GET['action'] ?? $_POST['action'] ?? 'list';
if ($action === 'import') {
    require_login();
}

$tid = (int)($_GET['tournament_id'] ?? $_POST['tournament_id'] ?? 0);
$sourceKey = $_GET['source'] ?? $_POST['source'] ?? 'enhanced_players';

// Available data source definitions
function getAvailableSources() {
    $sources = [
        'all' => [
            'id' => 'all',
            'name' => '✨ All Combined Sources',
            'type' => 'merged',
            'count' => 0
        ]
    ];

    // 1. Astro Registrations Log
    $regPath = 'C:/Users/abina/astrocirc/astrocircket-main/public_html/logs/registered_players.json';
    if (file_exists($regPath)) {
        $sources['registered_logs'] = [
            'id' => 'registered_logs',
            'name' => '🌐 Website Registrations (Live)',
            'path' => $regPath,
            'type' => 'json'
        ];
    }

    // 2. Full Astro Database (364 Players)
    $enhPath = 'C:/Users/abina/astrocirc/astrocircket-main/server/enhanced_players.json';
    if (file_exists($enhPath)) {
        $sources['enhanced_players'] = [
            'id' => 'enhanced_players',
            'name' => '🌟 Full Astro Database (364 Players)',
            'path' => $enhPath,
            'type' => 'json'
        ];
    }

    // 3. IPL & League Squads (665 Players)
    $leaguePath = 'C:/Users/abina/astrocirc/astrocircket-main/server/player_collector/all_players_final.json';
    if (file_exists($leaguePath)) {
        $sources['league_players'] = [
            'id' => 'league_players',
            'name' => '🏏 IPL & League Squads (665 Players)',
            'path' => $leaguePath,
            'type' => 'json'
        ];
    }

    // 4. Hostinger MySQL Database
    $sources['hostinger_db'] = [
        'id' => 'hostinger_db',
        'name' => '☁️ Hostinger Cloud MySQL (u682341828_astrocricket)',
        'type' => 'mysql'
    ];

    return $sources;
}

if ($action === 'sources') {
    echo json_encode(['ok' => true, 'sources' => array_values(getAvailableSources())]);
    exit;
}

function loadPlayersFromSource($key) {
    $players = [];
    $sources = getAvailableSources();

    // 1. Website Registrations
    if ($key === 'registered_logs' || $key === 'all') {
        if (isset($sources['registered_logs'])) {
            $c = @file_get_contents($sources['registered_logs']['path']);
            if ($c) {
                $c = preg_replace('/^\xEF\xBB\xBF/', '', $c);
                $arr = json_decode($c, true) ?: [];
                foreach ($arr as $p) {
                    $name = trim($p['name'] ?? '');
                    if (empty($name)) continue;
                    $players[] = [
                        'name' => $name,
                        'teamName' => trim($p['teamName'] ?? 'Astro Titans'),
                        'teamCity' => trim($p['teamCity'] ?? 'Chennai'),
                        'role' => strtoupper(trim($p['role'] ?? 'BAT')),
                        'jerseyNumber' => trim($p['jerseyNumber'] ?? ''),
                        'mobile' => trim($p['mobile'] ?? ''),
                        'dob' => trim($p['dob'] ?? ''),
                        'source' => 'Website Registration'
                    ];
                }
            }
        }
    }

    // 2. Astro Full DB (364 Players)
    if ($key === 'enhanced_players' || $key === 'all') {
        if (isset($sources['enhanced_players'])) {
            $c = @file_get_contents($sources['enhanced_players']['path']);
            if ($c) {
                $c = preg_replace('/^\xEF\xBB\xBF/', '', $c);
                $arr = json_decode($c, true) ?: [];
                foreach ($arr as $p) {
                    $pname = trim($p['name'] ?? '');
                    if (empty($pname)) continue;
                    $team = trim($p['teamName'] ?? ($p['birthPlace'] ? explode(',', $p['birthPlace'])[0] : 'Astro Squad'));
                    $players[] = [
                        'name' => $pname,
                        'teamName' => $team ?: 'Astro Squad',
                        'teamCity' => trim($p['birthPlace'] ?? ''),
                        'role' => strtoupper(trim($p['role'] ?? 'BAT')),
                        'jerseyNumber' => trim($p['jerseyNumber'] ?? ''),
                        'mobile' => trim($p['mobile'] ?? ''),
                        'dob' => trim($p['dob'] ?? $p['birthDate'] ?? ''),
                        'source' => 'Astro DB'
                    ];
                }
            }
        }
    }

    // 3. IPL & League Squads (665 Players)
    if ($key === 'league_players' || $key === 'all') {
        if (isset($sources['league_players'])) {
            $c = @file_get_contents($sources['league_players']['path']);
            if ($c) {
                $c = preg_replace('/^\xEF\xBB\xBF/', '', $c);
                $arr = json_decode($c, true) ?: [];
                foreach ($arr as $p) {
                    $pname = trim($p['name'] ?? '');
                    if (empty($pname)) continue;
                    $team = 'General Squad';
                    if (!empty($p['leagues']) && is_array($p['leagues']) && !empty($p['leagues'][0]['team'])) {
                        $team = $p['leagues'][0]['team'];
                    }
                    $players[] = [
                        'name' => $pname,
                        'teamName' => $team,
                        'teamCity' => '',
                        'role' => 'BAT',
                        'jerseyNumber' => '',
                        'mobile' => '',
                        'dob' => trim($p['birthDate'] ?? ''),
                        'source' => 'IPL/League'
                    ];
                }
            }
        }
    }

    // 4. Hostinger MySQL DB
    if ($key === 'hostinger_db') {
        try {
            $hPdo = new PDO('mysql:host=srv844.hstgr.io;dbname=u682341828_astrocricket;charset=utf8mb4', 'u682341828_astrocricket', 'aAstro@2026', [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 4
            ]);
            $st = $hPdo->query("SELECT id, name, country FROM players LIMIT 500");
            while ($r = $st->fetch(PDO::FETCH_ASSOC)) {
                $players[] = [
                    'name' => $r['name'],
                    'teamName' => $r['country'] ?: 'Global Team',
                    'teamCity' => $r['country'] ?: '',
                    'role' => 'BAT',
                    'jerseyNumber' => '',
                    'mobile' => '',
                    'dob' => '',
                    'source' => 'Hostinger MySQL'
                ];
            }
        } catch (Exception $e) {
            // Remote DB connection issue / fallback
        }
    }

    // Deduplicate by name if merged
    if ($key === 'all') {
        $seen = [];
        $unique = [];
        foreach ($players as $p) {
            $ln = strtolower(trim($p['name']));
            if (!isset($seen[$ln])) {
                $seen[$ln] = true;
                $unique[] = $p;
            }
        }
        return $unique;
    }

    return $players;
}

if ($action === 'list') {
    $allRaw = loadPlayersFromSource($sourceKey);

    // Fetch existing players in this tournament
    $existingPlayers = [];
    if ($tid > 0) {
        $pStmt = $pdo->prepare("
            SELECT LOWER(TRIM(p.name)) as pname 
            FROM players p 
            JOIN teams t ON p.team_id = t.id 
            WHERE t.tournament_id = ?
        ");
        $pStmt->execute([$tid]);
        while ($r = $pStmt->fetch(PDO::FETCH_ASSOC)) {
            $existingPlayers[] = $r['pname'];
        }
    }

    $formatted = [];
    $teamsSet = [];
    $unimportedCount = 0;

    foreach ($allRaw as $idx => $p) {
        $pname = trim($p['name'] ?? '');
        if (empty($pname)) continue;

        $tname = trim($p['teamName'] ?? 'General Team');
        $teamsSet[$tname] = true;
        $isImported = in_array(strtolower($pname), $existingPlayers);
        if (!$isImported) $unimportedCount++;

        $formatted[] = [
            'id' => $idx,
            'name' => $pname,
            'teamName' => $tname,
            'teamCity' => $p['teamCity'] ?? '',
            'role' => $p['role'] ?? 'BAT',
            'jerseyNumber' => $p['jerseyNumber'] ?? '',
            'mobile' => $p['mobile'] ?? '',
            'dob' => $p['dob'] ?? '',
            'source' => $p['source'] ?? 'Astro',
            'is_already_imported' => $isImported
        ];
    }

    echo json_encode([
        'ok' => true,
        'sources' => array_values(getAvailableSources()),
        'current_source' => $sourceKey,
        'total_count' => count($formatted),
        'unimported_count' => $unimportedCount,
        'teams_count' => count($teamsSet),
        'players' => $formatted
    ]);
    exit;
}

if ($action === 'import') {
    if ($tid <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Tournament ID is required']);
        exit;
    }

    $playersToImport = [];
    if (!empty($_POST['players_json'])) {
        $playersToImport = json_decode($_POST['players_json'], true) ?: [];
    }

    if (isset($_FILES['json_file']) && $_FILES['json_file']['error'] === UPLOAD_ERR_OK) {
        $content = file_get_contents($_FILES['json_file']['tmp_name']);
        $content = preg_replace('/^\xEF\xBB\xBF/', '', $content);
        $uploadedData = json_decode($content, true) ?: [];
        if (!empty($uploadedData)) {
            $playersToImport = $uploadedData;
        }
    }

    if (empty($playersToImport)) {
        http_response_code(400);
        echo json_encode(['error' => 'No players selected for import']);
        exit;
    }

    // Cache existing teams in this tournament
    $tStmt = $pdo->prepare("SELECT id, LOWER(TRIM(name)) as lname FROM teams WHERE tournament_id = ?");
    $tStmt->execute([$tid]);
    $teamMap = [];
    while ($r = $tStmt->fetch(PDO::FETCH_ASSOC)) {
        $teamMap[$r['lname']] = (int)$r['id'];
    }

    $insTeam = $pdo->prepare("INSERT INTO teams (name, short_name, icon, tournament_id) VALUES (?, ?, ?, ?)");
    $insPlayer = $pdo->prepare("INSERT INTO players (name, team_id, role, jersey_number, is_captain) VALUES (?, ?, ?, ?, ?)");
    $chkPlayer = $pdo->prepare("SELECT id FROM players WHERE team_id = ? AND LOWER(TRIM(name)) = ?");

    $teamsCreated = 0;
    $playersImported = 0;
    $playersSkipped = 0;

    foreach ($playersToImport as $p) {
        $playerName = trim($p['name'] ?? '');
        if (empty($playerName)) continue;

        $teamName = trim($p['teamName'] ?? 'Astro Squad');
        $lTeamName = strtolower($teamName);
        $role = strtoupper(trim($p['role'] ?? 'BAT'));
        $jersey = trim($p['jerseyNumber'] ?? '');

        // 1. Get or create team
        if (!isset($teamMap[$lTeamName])) {
            $shortName = strtoupper(substr(preg_replace('/[^A-Za-z0-9]/', '', $teamName), 0, 3));
            if (empty($shortName)) $shortName = 'AST';
            $icon = 'shield';
            
            $insTeam->execute([$teamName, $shortName, $icon, $tid]);
            $newTeamId = (int)$pdo->lastInsertId();
            $teamMap[$lTeamName] = $newTeamId;
            $teamsCreated++;
        }

        $targetTeamId = $teamMap[$lTeamName];

        // 2. Check duplicate
        $chkPlayer->execute([$targetTeamId, strtolower($playerName)]);
        if ($chkPlayer->fetch()) {
            $playersSkipped++;
            continue;
        }

        // 3. Insert Player
        $insPlayer->execute([$playerName, $targetTeamId, $role, $jersey, 0]);
        $playersImported++;
    }

    echo json_encode([
        'ok' => true,
        'imported_count' => $playersImported,
        'skipped_count' => $playersSkipped,
        'teams_created' => $teamsCreated,
        'message' => "Successfully imported {$playersImported} player(s) into tournament across {$teamsCreated} team(s)!"
    ]);
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'Invalid action']);
