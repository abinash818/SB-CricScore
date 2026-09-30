# SB CricScore - Project Core Instructions & Architecture Overview

> **Note for Antigravity Agent:** Read this document whenever starting or continuing work in this workspace. It summarizes the architecture, database schema, design standards, API endpoints, and development history of **SB CricScore**.

---

## 1. Project Overview
- **Project Name:** SB CricScore (formerly CricScore)
- **Primary Domain & URL:** `https://sbastro.com/tournament/` (or standalone root / Docker)
- **GitHub Repository:** [abinash818/SB-CricScore](https://github.com/abinash818/SB-CricScore)
- **Core Stack:** PHP 8+, Pure MySQL 8+ / MariaDB (Production on Hostinger), Vanilla JavaScript (ES6+), Vanilla CSS3 Design System, Flutter 3.x Mobile App.
- **Theme Palette:** Cosmic Midnight Dark (`#070710`), Luxury Gold (`#dfba73`, `#f5d77f`), Glassmorphism cards with border accents (`rgba(223, 186, 115, 0.15)`).

---

## 2. Directory Structure & Key Files
```text
Cricscores-main/
├── .env.example          # Sample MySQL database configuration
├── .gitignore            # Git exclusions (.env, data/backups/, etc.)
├── GEMINI.md             # Antigravity Context & Architecture Instructions (This file)
├── PROJECT_OVERVIEW.md   # Detailed feature list, API routes, and troubleshooting
├── README.md             # General project documentation
├── db.php                # Pure MySQL Database Connection Hub
├── init_db.php           # MySQL Database Schema Initializer & Auto-Migration Script

├── index.php             # Main Landing Page / Tournament & Match Explorer
├── manifest.json         # PWA Manifest (SB CricScore LIVE)
├── style.css             # Unified Luxury Midnight Gold Design System
├── sw.js                 # Service Worker (PWA offline caching)
├── assets/               # Logos, icons, branding assets
├── uploads/
│   └── players/          # Compressed profile pictures (max 400x400 ~35KB JPG)
├── api/                  # Backend REST & Action Handlers
│   ├── auth.php              # Session-based authentication & admin checks
│   ├── login.php / logout.php# Admin authentication handlers
│   ├── tournament_create.php # Create tournament & add initial teams (Relative pathing)
│   ├── tournament_edit.php   # Edit tournament details
│   ├── tournament_delete.php # Delete tournament & cascade data
│   ├── team_add.php          # Add team & 1-Click Clone Squad feature
│   ├── team_edit.php         # Edit team details
│   ├── team_delete.php       # Delete team & delete player photo files
│   ├── player_register.php   # Public/Captain player registration API + GD compression
│   ├── player_add.php        # Admin quick player addition
│   ├── player_edit.php       # Edit player details
│   ├── player_delete.php     # Delete player + photo file cleanup (@unlink)
│   ├── regular_players.php   # Manage global reusable regular players pool
│   ├── match_create.php      # Create match fixture
│   ├── match_get.php         # Live match state polling endpoint
│   ├── match_start.php       # Start match & toss recording
│   ├── match_result.php      # Finalize match results
│   ├── match_set_mom.php     # Set Man of the Match
│   ├── ball_add.php          # Record ball event (runs, extras, wickets)
│   ├── ball_undo.php         # Undo last ball
│   ├── ball_edit.php         # Edit previous ball details
│   ├── innings_complete.php  # Complete innings & swap teams
│   ├── super_over_start.php  # Initialize tie-breaker Super Over
│   ├── commentary_ops.php    # Live dynamic commentary strings management
│   ├── fixtures_generate.php # Auto generate Round Robin / Knockout fixtures
│   ├── points_table.php      # Points table data calculator (NRR, W, L, PTS)
│   ├── stats.php             # Tournament player statistics
│   ├── stats_global.php      # Global cross-tournament player statistics
│   ├── backup_ops.php        # SQLite database backup & restore
│   └── optimize_db.php       # DB index optimization & VACUUM
└── pages/                # Frontend Application Views
    ├── login.php             # Admin Login screen
    ├── tournament.php        # Tournament Hub (Fixtures, Teams, Squads, Points, Stats)
    ├── register_player.php   # Standalone Player Registration Page (Shareable WhatsApp link)
    ├── points.php            # Standalone Tournament Points Table & Standings
    ├── match.php             # Live Match Scoring & Spectator Match Center
    ├── players.php           # Global Player Stats & Directory
    ├── player.php            # Individual Player Career Profile & Performance Charts
    ├── commentary_manager.php# Admin Commentary Phrases Configuration
    └── settings.php          # Admin System Settings & Backup Manager
```

---

## 3. Database Schema (`init_db.php`)
The database contains the following tables (compatible with SQLite & MySQL):
1. **`tournaments`**: `id`, `name`, `type`, `win_points`, `tie_points`, `nr_points`, `loss_points`, `default_overs`, `default_wickets`, `created_at`
2. **`teams`**: `id`, `tournament_id`, `name`, `short_name`, `icon`
3. **`players`**: `id`, `team_id`, `name`, `dob`, `tob`, `pob`, `mobile`, `batting_style`, `bowling_style`, `profile_pic`, `is_captain`, `jersey_number`, `role`
4. **`matches`**: `id`, `tournament_id`, `team_a_id`, `team_b_id`, `overs_limit`, `wickets_limit`, `status`, `toss_winner_id`, `toss_decision`, `winner_id`, `win_margin`, `win_type`, `mom_player_id`, `created_at`
5. **`innings`**: `id`, `match_id`, `batting_team_id`, `bowling_team_id`, `innings_number`, `is_super_over`, `target_runs`, `status`
6. **`balls`**: `id`, `innings_id`, `over_number`, `ball_number`, `striker_id`, `non_striker_id`, `bowler_id`, `runs_bat`, `runs_extra`, `extra_type`, `is_wicket`, `dismissal_type`, `dismissal_player_id`, `fielder_id`, `commentary`
7. **`regular_players`**: `id`, `name`, `created_at`
8. **`users`**: `id`, `username`, `password_hash`, `role`
9. **`commentary_lines`**: `id`, `category`, `text`, `active`

---

## 4. Key Architectural Decisions & Best Practices

### A. Subfolder & Relative Path Compatibility
- **CRITICAL:** Always use relative paths for URLs and redirects (e.g., `tournament_create.php`, `../pages/tournament.php`, `style.css`, `assets/logo.png`).
- Never use root-absolute paths like `/api/...` or `/pages/...` because the app is often deployed in subfolders (e.g. `https://sbastro.com/tournament/`).

### B. Image Storage & Hostinger Inode Safety
- Profile pictures are uploaded to `uploads/players/`.
- Images are automatically resized and compressed via PHP GD (`imagejpeg` with quality 80, max 400x400) to keep size under ~35KB.
- When a player is deleted (`api/player_delete.php`) or a team is deleted (`api/team_delete.php`), the associated photo file is immediately unlinked (`@unlink`) to prevent ghost files.
- The database stores only the string relative path (`uploads/players/filename.jpg`), preserving database performance.

### C. 1-Click Squad & Team Cloning
- Teams are tied to specific `tournament_id`s in the database.
- Admins can clone any team and its squad (including photos) into another tournament with 1 click using `api/team_add.php` (`action=clone`).

### D. Standalone Shareable Player Registration
- Captains/Organizers can register players directly at `pages/register_player.php?team_id=X&tour_id=Y`.
- 1-click **"📲 Share on WhatsApp"** and **"📋 Copy Link"** buttons are provided.

---

## 5. Development & Deployment
- **Local Dev Server:** `php -S localhost:8080`
- **Hostinger Deployment:**
  - Copy all files into `public_html/tournament/` (or target directory).
  - Configure `.env` with MySQL credentials (`DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`).
  - Run `init_db.php` in browser once (e.g. `https://sbastro.com/tournament/init_db.php`) to create/update tables.
