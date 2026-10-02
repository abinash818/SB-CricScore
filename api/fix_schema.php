<?php
require_once __DIR__ . '/../db.php';
header('Content-Type: application/json');

$results = [];
try {
    $pdo->exec("ALTER TABLE `matches` MODIFY COLUMN `team_b_id` INT NULL DEFAULT NULL");
    $results['team_b_id_modify'] = 'SUCCESS';
} catch (Throwable $e) {
    $results['team_b_id_modify'] = 'ERROR: ' . $e->getMessage();
}

try {
    $pdo->exec("ALTER TABLE `matches` MODIFY COLUMN `toss_winner_team_id` INT NULL DEFAULT NULL");
    $results['toss_winner_modify'] = 'SUCCESS';
} catch (Throwable $e) {
    $results['toss_winner_modify'] = 'ERROR: ' . $e->getMessage();
}

try {
    $updated = $pdo->exec("
        UPDATE matches m
        SET status = 'completed'
        WHERE status IN ('live', 'in_progress')
    ");
    $results['cleaned_live_matches_count'] = $updated;
} catch (Throwable $e) {
    $results['cleaned_live_matches_error'] = $e->getMessage();
}

try {
    $pdo->exec("UPDATE innings SET completed = 1 WHERE match_id IN (SELECT id FROM matches WHERE status = 'completed')");
    $results['innings_completed_sync'] = 'SUCCESS';
} catch (Throwable $e) {
    $results['innings_completed_sync'] = $e->getMessage();
}

echo json_encode($results, JSON_PRETTY_PRINT);
