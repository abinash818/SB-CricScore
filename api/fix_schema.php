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

echo json_encode($results, JSON_PRETTY_PRINT);
