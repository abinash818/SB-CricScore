<?php
// api/optimize_db.php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/_helpers.php';

echo "<pre>";
echo "Starting Optimization...\n";

// 1. Add Summary Columns to 'innings' table
try {
    $pdo->exec("ALTER TABLE innings ADD COLUMN total_runs INTEGER DEFAULT 0");
    $pdo->exec("ALTER TABLE innings ADD COLUMN total_wickets INTEGER DEFAULT 0");
    $pdo->exec("ALTER TABLE innings ADD COLUMN total_legal_balls INTEGER DEFAULT 0");
    echo "✔ Added columns: total_runs, total_wickets, total_legal_balls\n";
} catch (Exception $e) {
    echo "ℹ Columns likely exist already.\n";
}

// 1B. Modify matches.team_b_id to nullable
try {
    $pdo->exec("ALTER TABLE `matches` MODIFY COLUMN `team_b_id` INT NULL DEFAULT NULL");
    echo "✔ Modified matches.team_b_id to NULLABLE\n";
} catch (Exception $e) {
    echo "ℹ team_b_id alter: " . $e->getMessage() . "\n";
}
try {
    $pdo->exec("ALTER TABLE `matches` MODIFY COLUMN `toss_winner_team_id` INT NULL DEFAULT NULL");
    echo "✔ Modified matches.toss_winner_team_id to NULLABLE\n";
} catch (Exception $e) {
    echo "ℹ toss_winner_team_id alter: " . $e->getMessage() . "\n";
}

// 2. Backfill Data
$stmt = $pdo->query("SELECT id FROM innings");
$ids = $stmt->fetchAll(PDO::FETCH_COLUMN);

foreach ($ids as $id) {
    // Calculate from raw ball events
    $stats = innings_totals_fresh($pdo, $id); 
    
    // Update the cache columns
    $upd = $pdo->prepare("UPDATE innings SET total_runs=?, total_wickets=?, total_legal_balls=? WHERE id=?");
    $upd->execute([$stats['runs'], $stats['wkts'], $stats['legal_balls'], $id]);
    
    echo "✔ Backfilled Innings #$id\n";
}

echo "Optimization Complete. Delete this file for security.";
?>