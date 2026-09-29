<?php
// update_db_v5.php - Database Migration for Single Match, QR Connect, Playing XI, YouTube Live & CricHeroes Extras
require_once __DIR__ . '/db.php';

$driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
echo "🔄 Running migration v5 on {$driver}...\n";

try {
    if ($driver === 'sqlite') {
        // 1. Users Table Columns
        $uCols = $pdo->query("PRAGMA table_info(users)")->fetchAll(PDO::FETCH_COLUMN, 1);
        if (!in_array('phone', $uCols)) {
            $pdo->exec("ALTER TABLE users ADD COLUMN phone TEXT DEFAULT NULL");
            $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone ON users(phone)");
        }
        if (!in_array('role', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'All-rounder'");
        if (!in_array('batting_style', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN batting_style TEXT DEFAULT 'Right Hand Bat'");
        if (!in_array('bowling_style', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN bowling_style TEXT DEFAULT 'Right Arm Medium'");
        if (!in_array('profile_pic', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN profile_pic TEXT DEFAULT NULL");
        if (!in_array('is_verified', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0");

        // 2. Matches Table Columns
        $mCols = $pdo->query("PRAGMA table_info(matches)")->fetchAll(PDO::FETCH_COLUMN, 1);
        if (!in_array('match_code', $mCols)) {
            $pdo->exec("ALTER TABLE matches ADD COLUMN match_code TEXT DEFAULT NULL");
            $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_code ON matches(match_code)");
        }
        if (!in_array('venue_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN venue_name TEXT DEFAULT NULL");
        if (!in_array('ball_type', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN ball_type TEXT DEFAULT 'tennis_light'");
        if (!in_array('invite_status', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN invite_status TEXT DEFAULT 'accepted'");
        if (!in_array('youtube_live_url', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN youtube_live_url TEXT DEFAULT NULL");
        if (!in_array('is_stream_active', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_stream_active INTEGER DEFAULT 0");

        // 3. Ball Events Free Hit Column
        $bCols = $pdo->query("PRAGMA table_info(ball_events)")->fetchAll(PDO::FETCH_COLUMN, 1);
        if (!in_array('is_free_hit', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN is_free_hit INTEGER DEFAULT 0");

        // 4. Playing XI Table
        $pdo->exec("
        CREATE TABLE IF NOT EXISTS match_playing_xi (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            match_id INTEGER NOT NULL,
            team_id INTEGER NOT NULL,
            player_id INTEGER NOT NULL,
            is_captain INTEGER DEFAULT 0,
            is_wicketkeeper INTEGER DEFAULT 0,
            is_substitute INTEGER DEFAULT 0,
            batting_order INTEGER DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            UNIQUE(match_id, player_id)
        );
        CREATE INDEX IF NOT EXISTS idx_playing_xi_match ON match_playing_xi(match_id);
        CREATE INDEX IF NOT EXISTS idx_playing_xi_team ON match_playing_xi(team_id);
        ");

        $xiCols = $pdo->query("PRAGMA table_info(match_playing_xi)")->fetchAll(PDO::FETCH_COLUMN, 1);
        if (!in_array('is_substitute', $xiCols)) {
            $pdo->exec("ALTER TABLE match_playing_xi ADD COLUMN is_substitute INTEGER DEFAULT 0");
        }

        // 5. Teams Table Columns
        $tCols = $pdo->query("PRAGMA table_info(teams)")->fetchAll(PDO::FETCH_COLUMN, 1);
        if (!in_array('owner_id', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN owner_id INTEGER DEFAULT NULL");
        if (!in_array('city', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN city TEXT DEFAULT NULL");

    } else {
        // MySQL Engine
        $uCols = $pdo->query("SHOW COLUMNS FROM users")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('phone', $uCols)) {
            $pdo->exec("ALTER TABLE users ADD COLUMN phone VARCHAR(30) DEFAULT NULL");
            $pdo->exec("ALTER TABLE users ADD UNIQUE KEY uq_users_phone (phone)");
        }
        if (!in_array('role', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN role VARCHAR(50) DEFAULT 'All-rounder'");
        if (!in_array('batting_style', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN batting_style VARCHAR(50) DEFAULT 'Right Hand Bat'");
        if (!in_array('bowling_style', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN bowling_style VARCHAR(50) DEFAULT 'Right Arm Medium'");
        if (!in_array('profile_pic', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN profile_pic VARCHAR(255) DEFAULT NULL");
        if (!in_array('is_verified', $uCols)) $pdo->exec("ALTER TABLE users ADD COLUMN is_verified TINYINT(1) DEFAULT 0");

        $mCols = $pdo->query("SHOW COLUMNS FROM matches")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('match_code', $mCols)) {
            $pdo->exec("ALTER TABLE matches ADD COLUMN match_code VARCHAR(30) DEFAULT NULL");
            $pdo->exec("ALTER TABLE matches ADD UNIQUE KEY uq_match_code (match_code)");
        }
        if (!in_array('venue_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN venue_name VARCHAR(150) DEFAULT NULL");
        if (!in_array('ball_type', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN ball_type VARCHAR(30) DEFAULT 'tennis_light'");
        if (!in_array('invite_status', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN invite_status VARCHAR(30) DEFAULT 'accepted'");
        if (!in_array('youtube_live_url', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN youtube_live_url VARCHAR(255) DEFAULT NULL");
        if (!in_array('is_stream_active', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_stream_active TINYINT(1) DEFAULT 0");

        $bCols = $pdo->query("SHOW COLUMNS FROM ball_events")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('is_free_hit', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN is_free_hit TINYINT(1) DEFAULT 0");

        $pdo->exec("
        CREATE TABLE IF NOT EXISTS match_playing_xi (
            id INT AUTO_INCREMENT PRIMARY KEY,
            match_id INT NOT NULL,
            team_id INT NOT NULL,
            player_id INT NOT NULL,
            is_captain TINYINT(1) DEFAULT 0,
            is_wicketkeeper TINYINT(1) DEFAULT 0,
            is_substitute TINYINT(1) DEFAULT 0,
            batting_order INT DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_match_player (match_id, player_id),
            INDEX idx_playing_xi_match (match_id),
            INDEX idx_playing_xi_team (team_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        try {
            $xiCols = $pdo->query("SHOW COLUMNS FROM match_playing_xi")->fetchAll(PDO::FETCH_COLUMN);
            if (!in_array('is_substitute', $xiCols)) {
                $pdo->exec("ALTER TABLE match_playing_xi ADD COLUMN is_substitute TINYINT(1) DEFAULT 0");
            }

            $tCols = $pdo->query("SHOW COLUMNS FROM teams")->fetchAll(PDO::FETCH_COLUMN);
            if (!in_array('owner_id', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN owner_id INT DEFAULT NULL");
            if (!in_array('city', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN city VARCHAR(100) DEFAULT NULL");
        } catch (Exception $e) {}
    }

    echo "✅ Migration v5 executed successfully on {$driver}!\n";

} catch (Exception $e) {
    echo "❌ Migration failed: " . $e->getMessage() . "\n";
}
