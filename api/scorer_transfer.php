<?php
// api/scorer_transfer.php
// Manages Scorer Handover & Single-Scorer Authorization
// POST /api/scorer_transfer.php

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$rawBody = file_get_contents('php://input');
$input = json_decode($rawBody, true) ?? $_POST;

$action = trim($_GET['action'] ?? ($input['action'] ?? 'transfer'));
$matchId = (int)($input['match_id'] ?? ($_GET['match_id'] ?? 0));

if ($matchId <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_id is required']);
    exit;
}

try {
    // 1. Fetch match details
    $mStmt = $pdo->prepare("SELECT * FROM matches WHERE id = ?");
    $mStmt->execute([$matchId]);
    $match = $mStmt->fetch(PDO::FETCH_ASSOC);

    if (!$match) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Match not found']);
        exit;
    }

    // Auto-migrate scorer columns if missing in DB
    try {
        $mCols = [];
        $st = $pdo->query("SHOW COLUMNS FROM matches");
        while ($r = $st->fetch(PDO::FETCH_ASSOC)) { $mCols[strtolower($r['Field'])] = true; }
        if (!isset($mCols['active_scorer_player_id'])) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_player_id INT DEFAULT NULL");
        if (!isset($mCols['active_scorer_name'])) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_name VARCHAR(100) DEFAULT NULL");
        if (!isset($mCols['active_scorer_mobile'])) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_mobile VARCHAR(30) DEFAULT NULL");
        if (!isset($mCols['scorer_pin'])) $pdo->exec("ALTER TABLE matches ADD COLUMN scorer_pin VARCHAR(10) DEFAULT NULL");

        $iCols = [];
        $st2 = $pdo->query("SHOW COLUMNS FROM innings");
        while ($r2 = $st2->fetch(PDO::FETCH_ASSOC)) { $iCols[strtolower($r2['Field'])] = true; }
        if (!isset($iCols['scorer_player_id'])) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_player_id INT DEFAULT NULL");
        if (!isset($iCols['scorer_name'])) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_name VARCHAR(100) DEFAULT NULL");
        if (!isset($iCols['scorer_mobile'])) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_mobile VARCHAR(30) DEFAULT NULL");
    } catch (Throwable $e) {}

    // Ensure match has a 4-digit PIN for emergency takeover
    $scorerPin = $match['scorer_pin'] ?? null;
    if (empty($scorerPin)) {
        $scorerPin = (string)mt_rand(1000, 9999);
        try {
            $pdo->prepare("UPDATE matches SET scorer_pin = ? WHERE id = ?")->execute([$scorerPin, $matchId]);
        } catch (Throwable $e) {}
    }

    // ── ACTION: GET STATUS ───────────────────────────────────────────────────
    if ($action === 'status' || $action === 'get_status') {
        $innStmt = $pdo->prepare("SELECT * FROM innings WHERE match_id = ? ORDER BY innings_no DESC LIMIT 1");
        $innStmt->execute([$matchId]);
        $activeInn = $innStmt->fetch(PDO::FETCH_ASSOC);

        $scorerPid = (int)($match['active_scorer_player_id'] ?? ($activeInn['scorer_player_id'] ?? 0));
        $scorerName = $match['active_scorer_name'] ?? ($activeInn['scorer_name'] ?? 'Scorekeeper');
        $scorerMobile = $match['active_scorer_mobile'] ?? ($activeInn['scorer_mobile'] ?? '');

        echo json_encode([
            'success'              => true,
            'match_id'             => $matchId,
            'active_scorer_id'     => $scorerPid,
            'active_scorer_name'   => $scorerName,
            'active_scorer_mobile' => $scorerMobile,
            'scorer_pin'           => $scorerPin,
            'innings_no'           => (int)($activeInn['innings_no'] ?? 1),
        ]);
        exit;
    }

    // ── ACTION: TRANSFER SCORER ──────────────────────────────────────────────
    if ($action === 'transfer' || $action === 'claim') {
        $targetPlayerId = (int)($input['target_player_id'] ?? ($input['player_id'] ?? 0));
        $targetName = trim($input['target_player_name'] ?? ($input['player_name'] ?? ''));
        $targetMobile = trim($input['target_player_mobile'] ?? ($input['mobile'] ?? ''));
        $providedPin = trim($input['scorer_pin'] ?? ($input['pin'] ?? ''));

        // If targetPlayerId is given, resolve player name and mobile if not provided
        if ($targetPlayerId > 0 && empty($targetName)) {
            $pStmt = $pdo->prepare("SELECT name, mobile FROM players WHERE id = ?");
            $pStmt->execute([$targetPlayerId]);
            $pRow = $pStmt->fetch(PDO::FETCH_ASSOC);
            if ($pRow) {
                $targetName = $pRow['name'];
                if (empty($targetMobile)) $targetMobile = $pRow['mobile'] ?? '';
            }
        }

        if (empty($targetName) && $targetPlayerId <= 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Target player or name is required for transfer']);
            exit;
        }

        if (empty($targetName)) $targetName = 'Scorekeeper';

        // 1. Update matches table
        $pdo->prepare("
            UPDATE matches 
            SET active_scorer_player_id = ?, active_scorer_name = ?, active_scorer_mobile = ? 
            WHERE id = ?
        ")->execute([
            ($targetPlayerId > 0 ? $targetPlayerId : null),
            $targetName,
            ($targetMobile ?: null),
            $matchId
        ]);

        // 2. Update current active innings table
        $innStmt = $pdo->prepare("SELECT id FROM innings WHERE match_id = ? ORDER BY innings_no DESC LIMIT 1");
        $innStmt->execute([$matchId]);
        $currInnId = (int)$innStmt->fetchColumn();

        if ($currInnId > 0) {
            $pdo->prepare("
                UPDATE innings 
                SET scorer_player_id = ?, scorer_name = ?, scorer_mobile = ? 
                WHERE id = ?
            ")->execute([
                ($targetPlayerId > 0 ? $targetPlayerId : null),
                $targetName,
                ($targetMobile ?: null),
                $currInnId
            ]);
        }

        echo json_encode([
            'success'              => true,
            'message'              => "Scoring successfully transferred to $targetName! 📲",
            'match_id'             => $matchId,
            'active_scorer_id'     => $targetPlayerId,
            'active_scorer_name'   => $targetName,
            'active_scorer_mobile' => $targetMobile,
            'scorer_pin'           => $scorerPin,
        ]);
        exit;
    }

    http_response_code(400);
    echo json_encode(['success' => false, 'message' => "Unknown action: $action"]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}
