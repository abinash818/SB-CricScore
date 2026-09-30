<?php
// db.php - Pure MySQL Database Connection (Hostinger Production & Local MySQL)

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

// Load .env configuration
loadEnvFile(__DIR__ . '/.env');

$driver = 'mysql';

$host   = getenv('DB_HOST') ?: 'localhost';
$port   = getenv('DB_PORT') ?: '3306';
$dbname = getenv('DB_NAME') ?: 'cricscore';
$user   = getenv('DB_USER') ?: 'root';
$pass   = getenv('DB_PASS') ?: '';

try {
    $dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    die(json_encode([
        'success' => false,
        'message' => 'MySQL Database Connection Error: ' . $e->getMessage()
    ]));
}