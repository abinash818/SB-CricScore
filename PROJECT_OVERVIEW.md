# 🏏 SB CricScore — Complete Project Documentation

**SB CricScore** is a web-based Cricket Tournament & Ball-by-Ball Live Scoring Application built with PHP, MySQL / SQLite, Vanilla JavaScript, and a modern Dark-Gold Design System.

---

## 📌 Table of Contents
1. [Core Features](#1-core-features)
2. [Folder & File Structure](#2-folder--file-structure)
3. [Database Architecture](#3-database-architecture)
4. [API Endpoints Reference](#4-api-endpoints-reference)
5. [Player Registration & Squad Engine](#5-player-registration--squad-engine)
6. [Hostinger Storage & Inode Safety](#6-hostinger-storage--inode-safety)
7. [Deployment Guide](#7-deployment-guide)

---

## 1. Core Features

- **🏆 Tournament Hub (`pages/tournament.php`)**
  - Create and manage Round Robin or Knockout tournaments.
  - Automatic points table calculation with Net Run Rate (NRR), Wins, Ties, Losses, Points.
  - Automatic single/double round robin or knockout fixture generation.
  - 1-Click Squad/Team duplication across tournaments.

- **🏏 Live Match Scoring Engine (`pages/match.php`)**
  - Ball-by-ball score entry: Batsman runs, bowler extras (wide, no-ball, bye, leg-bye, penalty), wickets (bowled, caught, run out, stumped, lbw, hit wicket, retired hurt).
  - Strike rotation logic, over change prompt, bowler selection.
  - Real-time undo ball and ball edit options.
  - Dynamic live commentary feed based on match actions.
  - Man of the Match (MOM) selection.
  - Super Over tie-breaker engine.

- **📱 Standalone Player Registration (`pages/register_player.php`)**
  - Mobile-first registration portal for team captains and managers.
  - Photo upload with client-side preview and server-side GD auto-compression.
  - Birth details: Date of Birth, Time of Birth, Birth Place.
  - Cricket attributes: Batting style, Bowling style, Jersey number, Captain badge, Playing role (BAT, BOWL, ALL, WK).
  - 1-Click **"📲 Share on WhatsApp"** and **"📋 Copy Link"** buttons.

- **📊 Statistics & Player Profiles (`pages/player.php` & `pages/players.php`)**
  - Global player directory with live search and sorting.
  - Individual player career profile with visual charts (Batting Runs, Strike Rate, Wickets, Economy, Dismissals).

- **🎨 Unified Luxury Dark-Gold Theme (`style.css`)**
  - Cosmic Midnight background (`#070710`).
  - Warm gold accents (`#dfba73`, `#f5d77f`).
  - Glassmorphic translucent cards with subtle glow borders.

---

## 2. Folder & File Structure

```text
├── .env.example          # Environment configuration template
├── .gitignore            # Git exclusion rules
├── GEMINI.md             # Antigravity context & memory file
├── PROJECT_OVERVIEW.md   # This documentation file
├── README.md             # Project readme
├── cric.db               # SQLite database file for local development
├── db.php                # Database connection factory (MySQL or SQLite)
├── init_db.php           # Database schema installer & auto-column migrator
├── index.php             # Main landing page / Tournament list
├── manifest.json         # PWA Manifest (SB CricScore LIVE)
├── style.css             # Unified CSS Design System
├── sw.js                 # PWA Service Worker
├── assets/               # Logos and icons
├── uploads/
│   └── players/          # Stored player profile photos (compressed ~35KB)
├── api/                  # Backend REST APIs and controllers
│   ├── auth.php              # Auth session checker
│   ├── login.php             # Admin login endpoint
│   ├── logout.php            # Logout endpoint
│   ├── tournament_create.php # Tournament creation & team onboarding
│   ├── tournament_edit.php   # Edit tournament details
│   ├── tournament_delete.php # Delete tournament & cascade
│   ├── team_add.php          # Add team & clone squad engine
│   ├── team_edit.php         # Edit team name/icon
│   ├── team_delete.php       # Delete team & delete photo files
│   ├── player_register.php   # Public/Captain player registration API
│   ├── player_add.php        # Quick add player
│   ├── player_edit.php       # Edit player details
│   ├── player_delete.php     # Delete player & delete photo file
│   ├── regular_players.php   # Reusable player pool API
│   ├── match_create.php      # Create match fixture
│   ├── match_get.php         # Get live match data & ball list
│   ├── match_start.php       # Record toss & start match
│   ├── match_result.php      # Declare match winner
│   ├── match_set_mom.php     # Award Man of the Match
│   ├── ball_add.php          # Record ball event
│   ├── ball_undo.php         # Undo last ball
│   ├── ball_edit.php         # Modify previous ball
│   ├── innings_complete.php  # Close innings & set target
│   ├── super_over_start.php  # Initialize super over
│   ├── commentary_ops.php    # Manage commentary phrases
│   ├── fixtures_generate.php # Auto generate tournament fixtures
│   ├── points_table.php      # Compute tournament points table & NRR
│   ├── stats.php             # Tournament stats
│   ├── stats_global.php      # Cross-tournament global stats
│   ├── backup_ops.php        # Backup and restore SQLite database
│   └── optimize_db.php       # Run VACUUM and ANALYZE
└── pages/                # Application Views
    ├── login.php             # Login page
    ├── tournament.php        # Tournament Hub
    ├── register_player.php   # Player registration screen
    ├── points.php            # Standalone Points Table
    ├── match.php             # Scoring & Spectator Match Center
    ├── players.php           # Global player stats
    ├── player.php            # Player career profile
    ├── commentary_manager.php# Commentary admin interface
    └── settings.php          # System settings & backup page
```

---

## 3. Database Architecture

### `tournaments`
- `id` (INT PK AI)
- `name` (VARCHAR)
- `type` (VARCHAR: `round_robin` or `knockout`)
- `win_points`, `tie_points`, `nr_points`, `loss_points` (INT)
- `default_overs`, `default_wickets` (INT)
- `created_at` (DATETIME)

### `teams`
- `id` (INT PK AI)
- `tournament_id` (INT FK)
- `name` (VARCHAR)
- `short_name` (VARCHAR 3-4 chars)
- `icon` (VARCHAR)

### `players`
- `id` (INT PK AI)
- `team_id` (INT FK)
- `name` (VARCHAR)
- `dob` (DATE) — Date of birth
- `tob` (VARCHAR) — Time of birth (e.g. 14:30)
- `pob` (VARCHAR) — Place of birth
- `mobile` (VARCHAR) — Contact number
- `batting_style` (VARCHAR) — Right Handed / Left Handed
- `bowling_style` (VARCHAR) — Right Arm Medium, Off Spin, etc.
- `profile_pic` (VARCHAR) — Path to photo `uploads/players/p_...jpg`
- `is_captain` (TINYINT: 0 or 1)
- `jersey_number` (VARCHAR)
- `role` (VARCHAR: `BAT`, `BOWL`, `ALL`, `WK`)

### `matches`
- `id` (INT PK AI)
- `tournament_id` (INT FK)
- `team_a_id`, `team_b_id` (INT FK)
- `overs_limit`, `wickets_limit` (INT)
- `status` (VARCHAR: `scheduled`, `live`, `completed`)
- `toss_winner_id`, `toss_decision` (INT, VARCHAR)
- `winner_id`, `win_margin`, `win_type`, `mom_player_id` (INT, VARCHAR)
- `created_at` (DATETIME)

### `innings`
- `id` (INT PK AI)
- `match_id` (INT FK)
- `batting_team_id`, `bowling_team_id` (INT FK)
- `innings_number` (INT: 1, 2, 3...)
- `is_super_over` (TINYINT: 0 or 1)
- `target_runs` (INT)
- `status` (VARCHAR: `in_progress`, `completed`)

### `balls`
- `id` (INT PK AI)
- `innings_id` (INT FK)
- `over_number`, `ball_number` (INT)
- `striker_id`, `non_striker_id`, `bowler_id` (INT FK)
- `runs_bat`, `runs_extra` (INT)
- `extra_type` (VARCHAR: `wide`, `no_ball`, `bye`, `leg_bye`, `penalty`)
- `is_wicket` (TINYINT: 0 or 1)
- `dismissal_type`, `dismissal_player_id`, `fielder_id` (VARCHAR, INT)
- `commentary` (TEXT)

---

## 4. Hostinger Inode & Storage Protection

1. **Lightweight Images:** Images uploaded via [pages/register_player.php](pages/register_player.php) are resized to a maximum of 400x400 px and compressed via PHP GD (`imagejpeg` 80% quality), resulting in lightweight files (~30KB–50KB).
2. **Zero Extra Files on Match Scoring:** All match balls, scores, commentary, overs, and standings are saved directly into MySQL database rows. No extra files are generated on disk during tournaments or live scoring.
3. **Auto Cleanup Engine:** Whenever a player is deleted ([api/player_delete.php](api/player_delete.php)) or a team is removed ([api/team_delete.php](api/team_delete.php)), all associated image files are automatically unlinked (`@unlink`) from disk.
4. **Estimated Usage:** 1,000 player registrations consume ~1,000 files total (only 0.3% of Hostinger's standard 300,000 Inode limit).

---

## 5. Deployment Instructions

### A. Deploy to Hostinger cPanel
1. Upload the files to `public_html/tournament/` (or target folder).
2. Create a MySQL database and user in Hostinger cPanel.
3. Create/edit `.env` file with your database credentials:
   ```ini
   DB_TYPE=mysql
   DB_HOST=localhost
   DB_NAME=u123456789_cricscore
   DB_USER=u123456789_admin
   DB_PASS=YourSecretPassword123
   ```
4. Visit `https://yourdomain.com/tournament/init_db.php` in your browser once. This will automatically create all tables and apply any new column migrations.
5. Access your app at `https://yourdomain.com/tournament/`.
