<?php
// init_db.php - Pure MySQL Database Schema Initializer & Auto-Migration Script
require_once __DIR__ . '/db.php';

try {
    // 1. Tournaments Table
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 2. Teams Table
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS teams (
      id INT AUTO_INCREMENT PRIMARY KEY,
      tournament_id INT NOT NULL,
      name VARCHAR(255) NOT NULL,
      short_name VARCHAR(10) DEFAULT NULL,
      icon VARCHAR(50) DEFAULT 'shield',
      group_name VARCHAR(50) DEFAULT NULL,
      owner_id INT DEFAULT NULL,
      city VARCHAR(100) DEFAULT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_teams_tourn (tournament_id),
      UNIQUE KEY uq_tour_team (tournament_id, name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 3. Players Table
    $pdo->exec("
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
      INDEX idx_players_team (team_id),
      INDEX idx_players_name (name),
      INDEX idx_players_mobile (mobile)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 4. Matches Table
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS matches (
      id INT AUTO_INCREMENT PRIMARY KEY,
      tournament_id INT,
      team_a_id INT NOT NULL,
      team_b_id INT DEFAULT NULL,
      overs_limit INT NOT NULL DEFAULT 20,
      wickets_limit INT NOT NULL DEFAULT 10,
      status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
      toss_winner_team_id INT,
      toss_decision VARCHAR(20), 
      winner_team_id INT,
      result_type VARCHAR(50),
      super_over TINYINT(1) NOT NULL DEFAULT 0,
      is_final TINYINT(1) DEFAULT 0, 
      man_of_match_id INT DEFAULT NULL,
      match_date VARCHAR(30) DEFAULT NULL,
      match_time VARCHAR(30) DEFAULT NULL,
      stage VARCHAR(50) DEFAULT 'League',
      match_code VARCHAR(30) DEFAULT NULL,
      venue_name VARCHAR(150) DEFAULT NULL,
      ball_type VARCHAR(30) DEFAULT 'tennis_light',
      invite_status VARCHAR(30) DEFAULT 'accepted',
      youtube_live_url VARCHAR(255) DEFAULT NULL,
      is_stream_active TINYINT(1) DEFAULT 0,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_matches_tourn (tournament_id),
      INDEX idx_matches_code (match_code)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 5. Innings Table
    $pdo->exec("
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 6. Ball Events Table
    $pdo->exec("
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
      is_free_hit TINYINT(1) DEFAULT 0,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_balls_innings (innings_id),
      INDEX idx_balls_batsman (striker_id),
      INDEX idx_balls_bowler (bowler_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 7. Users Table (Admin / Dashboard Login)
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      username VARCHAR(100) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      phone VARCHAR(30) DEFAULT NULL,
      role VARCHAR(50) DEFAULT 'Admin',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 8. App Users Table (Mobile App Registered Cricketers)
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 9. Mobile OTPs Table
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS mobile_otps (
      id INT AUTO_INCREMENT PRIMARY KEY,
      mobile VARCHAR(15) NOT NULL,
      otp VARCHAR(10) NOT NULL,
      attempts TINYINT NOT NULL DEFAULT 0,
      expires_at DATETIME NOT NULL,
      verified TINYINT(1) NOT NULL DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_otps_mobile (mobile)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 10. API Tokens Table (Mobile App Auth)
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS api_tokens (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      token VARCHAR(255) NOT NULL UNIQUE,
      expires_at DATETIME DEFAULT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_tokens_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 11. Match Playing XI Table (11+3 Substitutes)
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 12. Saved Global Players Pool
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS saved_players (
      id INT AUTO_INCREMENT PRIMARY KEY, 
      name VARCHAR(255) UNIQUE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 13. Dynamic Commentary Lines
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS commentary (
      id INT AUTO_INCREMENT PRIMARY KEY,
      trigger_event VARCHAR(50) NOT NULL, 
      context_tag VARCHAR(50) NOT NULL DEFAULT 'default',
      text_template TEXT NOT NULL,
      is_user_added TINYINT(1) DEFAULT 0,
      INDEX idx_comm_trigger (trigger_event)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 14. Feed Posts & Socials
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS feed_posts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT DEFAULT NULL,
      tournament_id INT DEFAULT NULL,
      match_id INT DEFAULT NULL,
      post_type VARCHAR(50) NOT NULL DEFAULT 'text',
      content TEXT NOT NULL,
      media_url VARCHAR(255) DEFAULT NULL,
      like_count INT DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_feed_tourn (tournament_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // 15. Notifications Table
    $pdo->exec("
    CREATE TABLE IF NOT EXISTS notifications (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      title VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      type VARCHAR(50) DEFAULT 'general',
      reference_id INT DEFAULT NULL,
      is_read TINYINT(1) DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_notif_user (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    // ── AUTO-MIGRATIONS FOR EXISTING MYSQL COLUMNS ──
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

    $tourCols = $pdo->query("SHOW COLUMNS FROM tournaments")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('state', $tourCols)) $pdo->exec("ALTER TABLE tournaments ADD COLUMN state VARCHAR(100) NOT NULL DEFAULT 'Tamil Nadu'");
    if (!in_array('district', $tourCols)) $pdo->exec("ALTER TABLE tournaments ADD COLUMN district VARCHAR(100) NOT NULL DEFAULT 'Coimbatore'");
    if (!in_array('city_area', $tourCols)) $pdo->exec("ALTER TABLE tournaments ADD COLUMN city_area VARCHAR(150) DEFAULT NULL");
    if (!in_array('venue_ground', $tourCols)) $pdo->exec("ALTER TABLE tournaments ADD COLUMN venue_ground VARCHAR(200) DEFAULT NULL");
    if (!in_array('pincode', $tourCols)) $pdo->exec("ALTER TABLE tournaments ADD COLUMN pincode VARCHAR(10) DEFAULT NULL");

    $mCols = $pdo->query("SHOW COLUMNS FROM matches")->fetchAll(PDO::FETCH_COLUMN);
    try { $pdo->exec("ALTER TABLE matches MODIFY COLUMN team_b_id INT NULL DEFAULT NULL"); } catch (Throwable $e) {}
    try { $pdo->exec("ALTER TABLE matches MODIFY COLUMN toss_winner_team_id INT NULL DEFAULT NULL"); } catch (Throwable $e) {}
    try { $pdo->exec("ALTER TABLE players ADD COLUMN team_role VARCHAR(20) DEFAULT 'member'"); } catch (Throwable $e) {}
    if (!in_array('is_final', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_final TINYINT(1) DEFAULT 0");
    if (!in_array('man_of_match_id', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN man_of_match_id INT DEFAULT NULL");
    if (!in_array('match_date', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_date VARCHAR(30) DEFAULT NULL");
    if (!in_array('match_time', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_time VARCHAR(30) DEFAULT NULL");
    if (!in_array('stage', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN stage VARCHAR(50) DEFAULT 'League'");
    if (!in_array('match_code', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN match_code VARCHAR(30) DEFAULT NULL");
    if (!in_array('venue_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN venue_name VARCHAR(150) DEFAULT NULL");
    if (!in_array('ball_type', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN ball_type VARCHAR(30) DEFAULT 'tennis_light'");
    if (!in_array('invite_status', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN invite_status VARCHAR(30) DEFAULT 'accepted'");
    if (!in_array('youtube_live_url', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN youtube_live_url VARCHAR(255) DEFAULT NULL");
    if (!in_array('is_stream_active', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN is_stream_active TINYINT(1) DEFAULT 0");
    if (!in_array('state', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN state VARCHAR(100) NOT NULL DEFAULT 'Tamil Nadu'");
    if (!in_array('district', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN district VARCHAR(100) NOT NULL DEFAULT 'Coimbatore'");
    if (!in_array('city_area', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN city_area VARCHAR(150) DEFAULT NULL");
    if (!in_array('pincode', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN pincode VARCHAR(10) DEFAULT NULL");
    if (!in_array('active_scorer_player_id', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_player_id INT DEFAULT NULL");
    if (!in_array('active_scorer_name', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_name VARCHAR(100) DEFAULT NULL");
    if (!in_array('active_scorer_mobile', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN active_scorer_mobile VARCHAR(30) DEFAULT NULL");
    if (!in_array('scorer_pin', $mCols)) $pdo->exec("ALTER TABLE matches ADD COLUMN scorer_pin VARCHAR(10) DEFAULT NULL");

    $iCols = $pdo->query("SHOW COLUMNS FROM innings")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('scorer_player_id', $iCols)) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_player_id INT DEFAULT NULL");
    if (!in_array('scorer_name', $iCols)) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_name VARCHAR(100) DEFAULT NULL");
    if (!in_array('scorer_mobile', $iCols)) $pdo->exec("ALTER TABLE innings ADD COLUMN scorer_mobile VARCHAR(30) DEFAULT NULL");

    $uCols = $pdo->query("SHOW COLUMNS FROM app_users")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('state', $uCols)) $pdo->exec("ALTER TABLE app_users ADD COLUMN state VARCHAR(100) DEFAULT 'Tamil Nadu'");
    if (!in_array('district', $uCols)) $pdo->exec("ALTER TABLE app_users ADD COLUMN district VARCHAR(100) DEFAULT 'Coimbatore'");

    $bCols = $pdo->query("SHOW COLUMNS FROM ball_events")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('is_free_hit', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN is_free_hit TINYINT(1) DEFAULT 0");
    if (!in_array('recorded_by_player_id', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN recorded_by_player_id INT DEFAULT NULL");
    if (!in_array('recorded_by_name', $bCols)) $pdo->exec("ALTER TABLE ball_events ADD COLUMN recorded_by_name VARCHAR(100) DEFAULT NULL");

    $xiCols = $pdo->query("SHOW COLUMNS FROM match_playing_xi")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('is_substitute', $xiCols)) $pdo->exec("ALTER TABLE match_playing_xi ADD COLUMN is_substitute TINYINT(1) DEFAULT 0");

    // Admin user default creation
    $adminUser = getenv('ADMIN_USER') ?: 'admin';
    $adminPass = getenv('ADMIN_PASS') ?: 'admin123';
    $userCount = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    if ($userCount === 0) {
        $hash = password_hash($adminPass, PASSWORD_DEFAULT);
        $stmt = $pdo->prepare('INSERT INTO users(username, password_hash) VALUES(?,?)');
        $stmt->execute([$adminUser, $hash]);
    }

    echo "✅ MySQL Database Initialized Successfully with Full Schema & Migrations!";
} catch (Exception $e) {
    die("❌ Schema Initialization Error: " . $e->getMessage());
}