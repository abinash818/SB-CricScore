<?php
// db.php - Universal Database Connection (SQLite & MySQL)

// Simple .env Loader
if (!function_exists('loadEnvFile')) {
    function loadEnvFile($path) {
        if (!file_exists($path)) return;
        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line) || strpos($line, '#') === 0) continue;
            if (strpos($line, '=') !== false) {
                list($name, $value) = explode('=', $line, 2);
                $name = trim($name);
                $value = trim($value, " \t\n\r\0\x0B\"'");
                if (!array_key_exists($name, $_SERVER) && !array_key_exists($name, $_ENV)) {
                    putenv("$name=$value");
                    $_ENV[$name] = $value;
                    $_SERVER[$name] = $value;
                }
            }
        }
    }
}

// Load .env if present
loadEnvFile(__DIR__ . '/.env');

$driver = strtolower(getenv('DB_DRIVER') ?: 'sqlite');

try {
    if ($driver === 'mysql') {
        $host = getenv('DB_HOST') ?: 'localhost';
        $port = getenv('DB_PORT') ?: '3306';
        $dbname = getenv('DB_NAME') ?: 'cricscore';
        $user = getenv('DB_USER') ?: 'root';
        $pass = getenv('DB_PASS') ?: '';
        
        $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
    } else {
        // SQLite
        $sqlitePath = getenv('SQLITE_PATH') ?: (__DIR__ . '/cric.db');
        if (!preg_match('/^[a-zA-Z]:|^[\/\\\\]/', $sqlitePath)) {
            $sqlitePath = __DIR__ . '/' . $sqlitePath;
        }
        $dir = dirname($sqlitePath);
        if (!is_dir($dir)) @mkdir($dir, 0775, true);

        $pdo = new PDO('sqlite:' . $sqlitePath);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

        // Enforce Foreign Keys & Journal mode
        $pdo->exec('PRAGMA foreign_keys = ON;');
        $pdo->exec('PRAGMA journal_mode = DELETE;');
        $pdo->exec('PRAGMA synchronous = FULL;');
    }
} catch (PDOException $e) {
    die("Database Connection Error: " . htmlspecialchars($e->getMessage()));
}