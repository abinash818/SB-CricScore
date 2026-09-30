<?php
// api/backup_ops.php - MySQL Database SQL Export & Backup Manager
require_once __DIR__ . '/../db.php';

session_start();
if (empty($_SESSION['user_id'])) {
    http_response_code(403);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

$action = $_REQUEST['action'] ?? '';
$backupDir = __DIR__ . '/../data/backups/'; 

if (!is_dir($backupDir)) {
    mkdir($backupDir, 0775, true);
    chmod($backupDir, 0775);
}

// 1. LIST ACTION
if ($action === 'list') {
    $files = glob($backupDir . "*.sql");
    $list = [];
    foreach ($files as $f) {
        $list[] = [
            'name' => basename($f),
            'size' => round(filesize($f) / 1024, 2) . ' KB',
            'date' => date("Y-m-d H:i:s", filemtime($f))
        ];
    }
    usort($list, function($a, $b) { return strcmp($b['date'], $a['date']); });
    header('Content-Type: application/json');
    echo json_encode($list);
    exit;
}

// 2. CREATE SQL BACKUP
elseif ($action === 'create') {
    try {
        $filename = 'cric_mysql_backup_' . date('Y-m-d_H-i-s') . '.sql';
        $dest = $backupDir . $filename;
        
        $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
        $sqlDump = "-- SB CricScore MySQL Database Backup\n-- Generated: " . date('Y-m-d H:i:s') . "\n\nSET FOREIGN_KEY_CHECKS=0;\n\n";

        foreach ($tables as $t) {
            $createTableStmt = $pdo->query("SHOW CREATE TABLE `$t`")->fetch(PDO::FETCH_ASSOC);
            $sqlDump .= "DROP TABLE IF EXISTS `$t`;\n" . $createTableStmt['Create Table'] . ";\n\n";

            $rows = $pdo->query("SELECT * FROM `$t`")->fetchAll(PDO::FETCH_ASSOC);
            if (!empty($rows)) {
                $cols = array_keys($rows[0]);
                $colNames = implode('`, `', $cols);
                foreach ($rows as $r) {
                    $vals = array_map(function($val) use ($pdo) {
                        return $val === null ? 'NULL' : $pdo->quote($val);
                    }, array_values($r));
                    $sqlDump .= "INSERT INTO `$t` (`$colNames`) VALUES (" . implode(', ', $vals) . ");\n";
                }
                $sqlDump .= "\n";
            }
        }
        $sqlDump .= "SET FOREIGN_KEY_CHECKS=1;\n";

        file_put_contents($dest, $sqlDump);
        echo json_encode(['success' => true, 'file' => $filename]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
    exit;
}

// 3. DELETE BACKUP
elseif ($action === 'delete') {
    $file = basename($_POST['file'] ?? '');
    $path = $backupDir . $file;
    if ($file && file_exists($path)) {
        unlink($path);
        echo json_encode(['success' => true]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'File not found']);
    }
    exit;
}

// 4. RESTORE BACKUP
elseif ($action === 'restore') {
    $file = basename($_POST['file'] ?? '');
    $source = $backupDir . $file;
    if ($file && file_exists($source)) {
        try {
            $sql = file_get_contents($source);
            $pdo->exec($sql);
            echo json_encode(['success' => true, 'message' => 'Database restored successfully!']);
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(['error' => 'Restore failed: ' . $e->getMessage()]);
        }
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Backup file not found']);
    }
    exit;
}