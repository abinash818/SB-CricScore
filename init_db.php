<?php
// init_db.php - Universal Schema Initialization for SQLite & MySQL
require_once __DIR__ . '/db.php';

$driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

if ($driver === 'sqlite') {
    $pdo->exec("PRAGMA journal_mode = DELETE;");
    $pdo->exec("PRAGMA synchronous = FULL;");

    $pdo->exec("
    CREATE TABLE IF NOT EXISTS tournaments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'round_robin',
      win_points INTEGER NOT NULL DEFAULT 2,
      tie_points INTEGER NOT NULL DEFAULT 1,
      nr_points  INTEGER NOT NULL DEFAULT 1,
      loss_points INTEGER NOT NULL DEFAULT 0,
      default_overs INTEGER NOT NULL DEFAULT 20,
      default_wickets INTEGER NOT NULL DEFAULT 10,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS teams (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tournament_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      short_name TEXT DEFAULT NULL,
      icon TEXT DEFAULT 'shield',
      UNIQUE(tournament_id, name)
    );

    CREATE TABLE IF NOT EXISTS players (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      team_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      role TEXT DEFAULT 'BAT',
      jersey_number TEXT DEFAULT '',
      is_captain INTEGER DEFAULT 0,
      profile_pic TEXT DEFAULT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);

    CREATE TABLE IF NOT EXISTS matches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tournament_id INTEGER,
      team_a_id INTEGER NOT NULL,
      team_b_id INTEGER NOT NULL,
      overs_limit INTEGER NOT NULL DEFAULT 20,
      wickets_limit INTEGER NOT NULL DEFAULT 10,
      status TEXT NOT NULL DEFAULT 'scheduled',
      toss_winner_team_id INTEGER,
      toss_decision TEXT, 
      winner_team_id INTEGER,
      result_type TEXT,
      super_over INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      is_final INTEGER DEFAULT 0, 
      man_of_match_id INTEGER DEFAULT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_matches_tourn ON matches(tournament_id);

    CREATE TABLE IF NOT EXISTS innings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      match_id INTEGER NOT NULL,
      innings_no INTEGER NOT NULL,
      batting_team_id INTEGER NOT NULL,
      bowling_team_id INTEGER NOT NULL,
      target INTEGER,
      completed INTEGER NOT NULL DEFAULT 0,
      is_super_over INTEGER NOT NULL DEFAULT 0,
      overs_limit_override INTEGER,
      total_runs INTEGER DEFAULT 0, 
      total_wickets INTEGER DEFAULT 0, 
      total_legal_balls INTEGER DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_innings_match ON innings(match_id);

    CREATE TABLE IF NOT EXISTS ball_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      innings_id INTEGER NOT NULL,
      seq INTEGER NOT NULL,
      striker_id INTEGER,
      non_striker_id INTEGER,
      bowler_id INTEGER,
      runs_bat INTEGER NOT NULL DEFAULT 0,
      extras_type TEXT,
      extras_runs INTEGER NOT NULL DEFAULT 0,
      is_wicket INTEGER NOT NULL DEFAULT 0,
      wicket_type TEXT,
      wicket_player_out_id INTEGER,
      is_legal INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_balls_innings ON ball_events(innings_id);
    CREATE INDEX IF NOT EXISTS idx_balls_batsman ON ball_events(striker_id);
    CREATE INDEX IF NOT EXISTS idx_balls_bowler ON ball_events(bowler_id);

    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS saved_players (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      name TEXT UNIQUE
    );

    CREATE TABLE IF NOT EXISTS commentary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trigger_event TEXT NOT NULL, 
      context_tag TEXT NOT NULL DEFAULT 'default',
      text_template TEXT NOT NULL,
      is_user_added INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS match_playing_xi (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      match_id INTEGER NOT NULL,
      team_id INTEGER NOT NULL,
      player_id INTEGER NOT NULL,
      is_captain INTEGER DEFAULT 0,
      is_wicketkeeper INTEGER DEFAULT 0,
      batting_order INTEGER DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      UNIQUE(match_id, player_id)
    );
    CREATE INDEX IF NOT EXISTS idx_playing_xi_match ON match_playing_xi(match_id);
    CREATE INDEX IF NOT EXISTS idx_playing_xi_team ON match_playing_xi(team_id);

    CREATE TABLE IF NOT EXISTS app_users (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      mobile       TEXT NOT NULL UNIQUE,
      name         TEXT DEFAULT NULL,
      dob          TEXT DEFAULT NULL,
      city         TEXT DEFAULT NULL,
      profile_pic  TEXT DEFAULT NULL,
      batting_style TEXT DEFAULT 'Right Hand Bat',
      bowling_style TEXT DEFAULT 'Right Arm Medium',
      role          TEXT DEFAULT 'All-Rounder',
      jersey_number TEXT DEFAULT NULL,
      preferred_format TEXT DEFAULT NULL,
      fcm_token    TEXT DEFAULT NULL,
      language     TEXT DEFAULT 'en',
      is_blocked   INTEGER DEFAULT 0,
      profile_complete INTEGER DEFAULT 0,
      created_at   TEXT NOT NULL DEFAULT (datetime('now')),
      last_login   TEXT DEFAULT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_mobile ON app_users(mobile);

    CREATE TABLE IF NOT EXISTS mobile_otps (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      mobile    TEXT NOT NULL,
      otp       TEXT NOT NULL,
      attempts  INTEGER NOT NULL DEFAULT 0,
      expires_at TEXT NOT NULL,
      verified  INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_otps_mobile ON mobile_otps(mobile);

    CREATE TABLE IF NOT EXISTS api_tokens (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    INTEGER NOT NULL,
      token      TEXT NOT NULL UNIQUE,
      expires_at TEXT DEFAULT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_tokens_token ON api_tokens(token);
    CREATE INDEX IF NOT EXISTS idx_tokens_user ON api_tokens(user_id);
    ");


    // Auto-upgrade existing SQLite tables with new columns if missing
    $pCols = $pdo->query("PRAGMA table_info(players)")->fetchAll(PDO::FETCH_COLUMN, 1);
    if (!in_array('role', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN role TEXT DEFAULT 'BAT'");
    if (!in_array('jersey_number', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN jersey_number TEXT DEFAULT ''");
    if (!in_array('profile_pic', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN profile_pic TEXT DEFAULT NULL");
    if (!in_array('is_captain', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN is_captain INTEGER DEFAULT 0");
    if (!in_array('mobile', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN mobile TEXT DEFAULT ''");
    if (!in_array('dob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN dob TEXT DEFAULT ''");
    if (!in_array('tob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN tob TEXT DEFAULT ''");
    if (!in_array('pob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN pob TEXT DEFAULT ''");
    if (!in_array('batting_style', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN batting_style TEXT DEFAULT 'Right Hand Bat'");
    if (!in_array('bowling_style', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN bowling_style TEXT DEFAULT 'Right Arm Medium'");

    $tCols = $pdo->query("PRAGMA table_info(teams)")->fetchAll(PDO::FETCH_COLUMN, 1);
    if (!in_array('short_name', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN short_name TEXT DEFAULT NULL");
    if (!in_array('icon', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN icon TEXT DEFAULT 'shield'");
    if (!in_array('group_name', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN group_name TEXT DEFAULT NULL");
    if (!in_array('owner_id', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN owner_id INTEGER DEFAULT NULL");
    if (!in_array('city', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN city TEXT DEFAULT NULL");

    $mCols = $pdo->query("PRAGMA table_info(matches)")->fetchAll(PDO::FETCH_COLUMN, 1);
    if (!in_array('is_final', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_final INTEGER DEFAULT 0");
    if (!in_array('man_of_match_id', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN man_of_match_id INTEGER DEFAULT NULL");
    if (!in_array('match_date', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_date TEXT DEFAULT NULL");
    if (!in_array('match_time', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_time TEXT DEFAULT NULL");
    if (!in_array('stage', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN stage TEXT DEFAULT 'League'");
    if (!in_array('match_code', $mCols)) {
        $pdo->exec("ALTER TABLE matches ADD COLUMN match_code TEXT DEFAULT NULL");
        $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_code ON matches(match_code)");
    }
    if (!in_array('venue_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN venue_name TEXT DEFAULT NULL");
    if (!in_array('ball_type', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN ball_type TEXT DEFAULT 'tennis_light'");
    if (!in_array('invite_status', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN invite_status TEXT DEFAULT 'accepted'");
    if (!in_array('youtube_live_url', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN youtube_live_url TEXT DEFAULT NULL");
    if (!in_array('is_stream_active', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_stream_active INTEGER DEFAULT 0");

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

    $bCols = $pdo->query("PRAGMA table_info(ball_events)")->fetchAll(PDO::FETCH_COLUMN, 1);
    if (!in_array('is_free_hit', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN is_free_hit INTEGER DEFAULT 0");

} else {
    // MySQL DDL for Hostinger
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS tournaments (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      type VARCHAR(50) NOT NULL DEFAULT 'round_robin',
      win_points INT NOT NULL DEFAULT 2,
      tie_points INT NOT NULL DEFAULT 1,
      nr_points  INT NOT NULL DEFAULT 1,
      loss_points INT NOT NULL DEFAULT 0,
      default_overs INT NOT NULL DEFAULT 20,
      default_wickets INT NOT NULL DEFAULT 10,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS teams (
      id INT AUTO_INCREMENT PRIMARY KEY,
      tournament_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      short_name VARCHAR(10) DEFAULT NULL,
      icon VARCHAR(50) DEFAULT 'shield',
      group_name VARCHAR(50) DEFAULT NULL,
      UNIQUE KEY uq_tour_team (tournament_id, name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS players (
      id INT AUTO_INCREMENT PRIMARY KEY,
      team_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      role VARCHAR(50) DEFAULT 'BAT',
      jersey_number VARCHAR(20) DEFAULT '',
      is_captain TINYINT(1) DEFAULT 0,
      profile_pic VARCHAR(255) DEFAULT NULL,
      mobile VARCHAR(30) DEFAULT '',
      dob VARCHAR(30) DEFAULT '',
      tob VARCHAR(20) DEFAULT '',
      pob VARCHAR(100) DEFAULT '',
      batting_style VARCHAR(50) DEFAULT 'Right Hand Bat',
      bowling_style VARCHAR(50) DEFAULT 'Right Arm Medium',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_players_team (team_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS matches (
      id INT AUTO_INCREMENT PRIMARY KEY,
      tournament_id INT,
      team_a_id INT NOT NULL,
      team_b_id INT NOT NULL,
      overs_limit INT NOT NULL DEFAULT 20,
      wickets_limit INT NOT NULL DEFAULT 10,
      status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
      toss_winner_team_id INT,
      toss_decision VARCHAR(20), 
      winner_team_id INT,
      result_type VARCHAR(50),
      super_over TINYINT(1) NOT NULL DEFAULT 0,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      is_final TINYINT(1) DEFAULT 0, 
      man_of_match_id INT DEFAULT NULL,
      INDEX idx_matches_tourn (tournament_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS innings (
      id INT AUTO_INCREMENT PRIMARY KEY,
      match_id INT NOT NULL,
      innings_no INT NOT NULL,
      batting_team_id INT NOT NULL,
      bowling_team_id INT NOT NULL,
      target INT,
      completed TINYINT(1) NOT NULL DEFAULT 0,
      is_super_over TINYINT(1) NOT NULL DEFAULT 0,
      overs_limit_override INT,
      total_runs INT DEFAULT 0, 
      total_wickets INT DEFAULT 0, 
      total_legal_balls INT DEFAULT 0,
      INDEX idx_innings_match (match_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS ball_events (
      id INT AUTO_INCREMENT PRIMARY KEY,
      innings_id INT NOT NULL,
      seq INT NOT NULL,
      striker_id INT,
      non_striker_id INT,
      bowler_id INT,
      runs_bat INT NOT NULL DEFAULT 0,
      extras_type VARCHAR(20),
      extras_runs INT NOT NULL DEFAULT 0,
      is_wicket TINYINT(1) NOT NULL DEFAULT 0,
      wicket_type VARCHAR(50),
      wicket_player_out_id INT,
      is_legal TINYINT(1) NOT NULL DEFAULT 1,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_balls_innings (innings_id),
      INDEX idx_balls_batsman (striker_id),
      INDEX idx_balls_bowler (bowler_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(100) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS saved_players (
      id INT AUTO_INCREMENT PRIMARY KEY, 
      name VARCHAR(255) UNIQUE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

    CREATE TABLE IF NOT EXISTS commentary (
      id INT AUTO_INCREMENT PRIMARY KEY,
      trigger_event VARCHAR(50) NOT NULL, 
      context_tag VARCHAR(50) NOT NULL DEFAULT 'default',
      text_template TEXT NOT NULL,
      is_user_added TINYINT(1) DEFAULT 0,
      INDEX idx_comm_trigger (trigger_event)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    // Auto-upgrade existing MySQL columns if missing
    try {
        $tCols = $pdo->query("SHOW COLUMNS FROM teams")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('group_name', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN group_name VARCHAR(50) DEFAULT NULL");
        if (!in_array('short_name', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN short_name VARCHAR(10) DEFAULT NULL");
        if (!in_array('icon', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN icon VARCHAR(50) DEFAULT 'shield'");
        if (!in_array('owner_id', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN owner_id INT DEFAULT NULL");
        if (!in_array('city', $tCols)) $pdo->exec("ALTER TABLE teams ADD COLUMN city VARCHAR(100) DEFAULT NULL");

        $pCols = $pdo->query("SHOW COLUMNS FROM players")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('mobile', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN mobile VARCHAR(30) DEFAULT ''");
        if (!in_array('dob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN dob VARCHAR(30) DEFAULT ''");
        if (!in_array('tob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN tob VARCHAR(20) DEFAULT ''");
        if (!in_array('pob', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN pob VARCHAR(100) DEFAULT ''");
        if (!in_array('batting_style', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN batting_style VARCHAR(50) DEFAULT 'Right Hand Bat'");
        if (!in_array('bowling_style', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN bowling_style VARCHAR(50) DEFAULT 'Right Arm Medium'");
        if (!in_array('profile_pic', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN profile_pic VARCHAR(255) DEFAULT NULL");
        if (!in_array('is_captain', $pCols)) $pdo->exec("ALTER TABLE players ADD COLUMN is_captain TINYINT(1) DEFAULT 0");

        $mCols = $pdo->query("SHOW COLUMNS FROM matches")->fetchAll(PDO::FETCH_COLUMN);
        if (!in_array('is_final', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_final TINYINT(1) DEFAULT 0");
        if (!in_array('man_of_match_id', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN man_of_match_id INT DEFAULT NULL");
        if (!in_array('match_date', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_date VARCHAR(30) DEFAULT NULL");
        if (!in_array('match_time', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_time VARCHAR(30) DEFAULT NULL");
        if (!in_array('stage', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League'");
        if (!in_array('match_code', $mCols)) {
            $pdo->exec("ALTER TABLE matches ADD COLUMN match_code VARCHAR(30) DEFAULT NULL");
            $pdo->exec("ALTER TABLE matches ADD UNIQUE KEY uq_match_code (match_code)");
        }
        if (!in_array('venue_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN venue_name VARCHAR(150) DEFAULT NULL");
        if (!in_array('ball_type', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN ball_type VARCHAR(30) DEFAULT 'tennis_light'");
        if (!in_array('invite_status', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN invite_status VARCHAR(30) DEFAULT 'accepted'");
        if (!in_array('youtube_live_url', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN youtube_live_url VARCHAR(255) DEFAULT NULL");
        if (!in_array('is_stream_active', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_stream_active TINYINT(1) DEFAULT 0");

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

        $pdo->exec("
        CREATE TABLE IF NOT EXISTS app_users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            mobile VARCHAR(15) NOT NULL UNIQUE,
            name VARCHAR(100) DEFAULT NULL,
            dob DATE DEFAULT NULL,
            city VARCHAR(100) DEFAULT NULL,
            profile_pic VARCHAR(255) DEFAULT NULL,
            batting_style VARCHAR(50) DEFAULT 'Right Hand Bat',
            bowling_style VARCHAR(50) DEFAULT 'Right Arm Medium',
            role VARCHAR(50) DEFAULT 'All-Rounder',
            jersey_number VARCHAR(10) DEFAULT NULL,
            preferred_format VARCHAR(20) DEFAULT NULL,
            fcm_token VARCHAR(255) DEFAULT NULL,
            language VARCHAR(10) DEFAULT 'en',
            is_blocked TINYINT(1) DEFAULT 0,
            profile_complete TINYINT(1) DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_login DATETIME DEFAULT NULL,
            UNIQUE KEY uq_app_users_mob (mobile)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS mobile_otps (
            id INT AUTO_INCREMENT PRIMARY KEY,
            mobile VARCHAR(15) NOT NULL,
            otp VARCHAR(10) NOT NULL,
            attempts TINYINT NOT NULL DEFAULT 0,
            expires_at DATETIME NOT NULL,
            verified TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_otps_mobile (mobile)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS api_tokens (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            token VARCHAR(255) NOT NULL UNIQUE,
            expires_at DATETIME DEFAULT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_tokens_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");
    } catch (Exception $e) {}

}

// Admin user setup
$adminUser = getenv('ADMIN_USER') ?: 'admin';
$adminPass = getenv('ADMIN_PASS') ?: 'admin123';
$userCount = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
if ($userCount === 0) {
  $hash = password_hash($adminPass, PASSWORD_DEFAULT);
  $stmt = $pdo->prepare('INSERT INTO users(username, password_hash) VALUES(?,?)');
  $stmt->execute([$adminUser, $hash]);
}

echo "✅ Database Initialized Successfully for {$driver}!";