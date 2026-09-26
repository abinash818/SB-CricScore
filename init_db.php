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
    CREATE INDEX IF NOT EXISTS idx_comm_trigger ON commentary(trigger_event);
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