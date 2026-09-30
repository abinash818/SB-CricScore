<?php
require_once __DIR__ . '/../db.php';

$pid = (int)($_GET['id'] ?? 0);
if(!$pid) die("Invalid Player");

// 1. Get Player Name & Profile Info
$stmt = $pdo->prepare("SELECT * FROM players WHERE id=?");
$stmt->execute([$pid]);
$playerRow = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$playerRow) die("Player not found");
$pName = $playerRow['name'];

// 2. Find ALL IDs for this player (to aggregate global stats)
$idsStmt = $pdo->prepare("SELECT id FROM players WHERE name=?");
$idsStmt->execute([$pName]);
$allIds = $idsStmt->fetchAll(PDO::FETCH_COLUMN);

if (empty($allIds)) die("No data found");

$inClause = implode(',', array_map('intval', $allIds));

// 3. Global Batting Stats
$batSql = "
    SELECT 
        COUNT(DISTINCT m.id) as matches, 
        SUM(b.runs_bat) as runs, 
        COUNT(b.id) as balls, 
        SUM(CASE WHEN b.runs_bat=4 THEN 1 ELSE 0 END) as fours, 
        SUM(CASE WHEN b.runs_bat=6 THEN 1 ELSE 0 END) as sixes
    FROM ball_events b 
    JOIN innings i ON b.innings_id=i.id 
    JOIN matches m ON i.match_id=m.id 
    WHERE b.striker_id IN ($inClause)
";
$bStats = $pdo->query($batSql)->fetch(PDO::FETCH_ASSOC);

// 4. Batting History for Charts & Milestones
$histSql = "
    SELECT SUM(b.runs_bat) as runs, 
           MAX(CASE WHEN b.is_wicket=1 AND b.wicket_player_out_id IN ($inClause) THEN 1 ELSE 0 END) as is_out
    FROM ball_events b 
    WHERE b.striker_id IN ($inClause)
    GROUP BY b.innings_id
";
$hist = $pdo->query($histSql)->fetchAll(PDO::FETCH_ASSOC);

$hs = 0; $fifties = 0; $hundreds = 0; $innings_count = 0; $not_outs = 0;

foreach($hist as $h) {
    $r = (int)$h['runs'];
    if($r > $hs) $hs = $r;
    if($r >= 50 && $r < 100) $fifties++;
    if($r >= 100) $hundreds++;
    if($h['is_out'] == 0) $not_outs++;
    $innings_count++;
}
$bStats['hs'] = $hs;

// 5. Global Bowling Stats (Updated for WD/NB)
$bowlSql = "
    SELECT 
        COUNT(DISTINCT m.id) as matches,
        SUM(CASE WHEN b.is_wicket=1 AND b.wicket_type != 'run out' THEN 1 ELSE 0 END) as wickets, 
        COUNT(CASE WHEN b.is_legal=1 THEN 1 END) as legal_balls, 
        SUM(b.runs_bat + b.extras_runs) as runs_conceded,
        COUNT(CASE WHEN b.extras_type='wd' THEN 1 END) as wides,
        COUNT(CASE WHEN b.extras_type='nb' THEN 1 END) as no_balls
    FROM ball_events b 
    JOIN innings i ON b.innings_id=i.id 
    JOIN matches m ON i.match_id=m.id 
    WHERE b.bowler_id IN ($inClause)
";
$oStats = $pdo->query($bowlSql)->fetch(PDO::FETCH_ASSOC);

// 6. Bowling Milestones & BBI (Best Bowling Innings)
$bowlHistSql = "
    SELECT 
        COUNT(CASE WHEN is_wicket=1 AND wicket_type != 'run out' THEN 1 END) as wkts,
        SUM(runs_bat + extras_runs) as runs
    FROM ball_events
    WHERE bowler_id IN ($inClause)
    GROUP BY innings_id
";
$bowlHist = $pdo->query($bowlHistSql)->fetchAll(PDO::FETCH_ASSOC);

$best_wkts = 0; $best_runs = 1000;
$w3 = 0; $w5 = 0;

foreach($bowlHist as $bh) {
    $w = (int)$bh['wkts'];
    $r = (int)$bh['runs'];
    
    // Check Best Bowling (More wickets, or same wickets for less runs)
    if ($w > $best_wkts) { $best_wkts = $w; $best_runs = $r; }
    elseif ($w == $best_wkts && $r < $best_runs) { $best_runs = $r; }
    
    if ($w >= 3) $w3++;
    if ($w >= 5) $w5++;
}
$bbi = ($best_wkts > 0) ? "$best_wkts/$best_runs" : "-";

// 7. Global Awards
$momSql = "SELECT COUNT(*) FROM matches WHERE man_of_match_id IN ($inClause)";
$momCount = $pdo->query($momSql)->fetchColumn();

// 8. Teams
$teamSql = "
    SELECT DISTINCT t.name as team_name, t.icon as team_icon, tr.name as tour_name 
    FROM players p 
    JOIN teams t ON p.team_id=t.id 
    JOIN tournaments tr ON t.tournament_id=tr.id 
    WHERE p.name = ?
    ORDER BY tr.id DESC
";
$tStmt = $pdo->prepare($teamSql);
$tStmt->execute([$pName]);
$teamsList = $tStmt->fetchAll(PDO::FETCH_ASSOC);

// 9. Charts Data
$chartSql = "
    SELECT m.id, SUM(b.runs_bat) as runs, 
           MAX(CASE WHEN b.is_wicket=1 AND b.wicket_player_out_id IN ($inClause) THEN 1 ELSE 0 END) as is_out
    FROM ball_events b 
    JOIN innings i ON b.innings_id=i.id 
    JOIN matches m ON i.match_id=m.id 
    WHERE b.striker_id IN ($inClause)
    GROUP BY m.id, i.innings_no
    ORDER BY m.id ASC LIMIT 20
";
$chartData = $pdo->query($chartSql)->fetchAll(PDO::FETCH_ASSOC);
$graphLabels = []; $graphRuns = []; $graphColors = [];
foreach($chartData as $cd) {
    $graphLabels[] = "Match " . $cd['id'];
    $graphRuns[] = (int)$cd['runs'];
    $graphColors[] = ($cd['is_out'] == 1) ? '#ff5252' : '#00e676';
}

// Calculations
$totalMatches = max((int)$bStats['matches'], (int)$oStats['matches']);

// Batting Metrics
$outs = $innings_count - $not_outs;
$bat_avg = ($outs > 0) ? round($bStats['runs'] / $outs, 2) : (int)$bStats['runs'];
$bat_sr = ($bStats['balls'] > 0) ? round(($bStats['runs'] / $bStats['balls']) * 100, 1) : 0;

// Bowling Metrics
$overs = $oStats['legal_balls'] / 6;
$bowl_econ = ($overs > 0) ? round($oStats['runs_conceded'] / $overs, 2) : 0;
$bowl_avg = ($oStats['wickets'] > 0) ? round($oStats['runs_conceded'] / $oStats['wickets'], 2) : 0;
$bowl_sr = ($oStats['wickets'] > 0) ? round($oStats['legal_balls'] / $oStats['wickets'], 1) : 0;

?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
    <link rel="stylesheet" href="../style.css"/>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
    <title><?= htmlspecialchars($pName) ?> - SB CricScore Career Profile</title>
    <link rel="manifest" href="../manifest.json">
    <link rel="icon" type="image/png" href="../assets/logo.png">
    <link rel="apple-touch-icon" href="../assets/icon-192.png">
    <meta name="theme-color" content="#070710">
    <style>
        .profile-hero {
            background: linear-gradient(180deg, rgba(223, 186, 115, 0.12) 0%, rgba(19, 19, 38, 0.8) 100%);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-lg);
            padding: 28px 20px;
            text-align: center;
            margin-bottom: 20px;
            position: relative;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(10px);
        }
        .profile-avatar-wrap {
            width: 104px;
            height: 104px;
            border-radius: 50%;
            margin: 0 auto 14px;
            overflow: hidden;
            border: 3px solid var(--gold-primary);
            box-shadow: var(--gold-glow);
            display: flex;
            align-items: center;
            justify-content: center;
            background: #131326;
            position: relative;
        }
        .profile-avatar-wrap img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .hero-name {
            font-size: 26px;
            font-weight: 800;
            margin: 0;
            background: var(--gold-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-family: var(--font-head);
        }
        .profile-badges {
            display: flex;
            justify-content: center;
            gap: 8px;
            align-items: center;
            margin-top: 8px;
            flex-wrap: wrap;
        }
        .pill-badge {
            font-size: 12px;
            padding: 3px 10px;
            border-radius: 20px;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .pill-role {
            background: rgba(223, 186, 115, 0.15);
            color: var(--gold-light);
            border: 1px solid rgba(223, 186, 115, 0.35);
        }
        .pill-jersey {
            background: rgba(6, 182, 212, 0.15);
            color: var(--neon-cyan);
            border: 1px solid rgba(6, 182, 212, 0.35);
        }
        .pill-captain {
            background: rgba(245, 158, 11, 0.2);
            color: #fcd34d;
            border: 1px solid rgba(245, 158, 11, 0.5);
        }
        .pill-matches {
            background: rgba(16, 185, 129, 0.15);
            color: var(--neon-green);
            border: 1px solid rgba(16, 185, 129, 0.35);
        }

        /* Touch Tab Switcher */
        .career-tab-bar {
            display: flex;
            gap: 8px;
            background: #0d0d1c;
            padding: 6px;
            border-radius: 14px;
            border: 1px solid var(--border-subtle);
            margin-bottom: 22px;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            scrollbar-width: none;
        }
        .career-tab-bar::-webkit-scrollbar { display: none; }
        .touch-tab-btn {
            flex: 1;
            min-width: 120px;
            padding: 10px 14px;
            border-radius: 10px;
            border: none;
            background: transparent;
            color: var(--text-muted);
            font-family: var(--font-head);
            font-size: 13px;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            cursor: pointer;
            transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
            user-select: none;
            -webkit-tap-highlight-color: transparent;
            white-space: nowrap;
        }
        .touch-tab-btn:active {
            transform: scale(0.96);
        }
        .touch-tab-btn.active {
            background: var(--gold-gradient);
            color: #070710;
            box-shadow: 0 4px 15px rgba(223, 186, 115, 0.35);
        }
        .touch-tab-btn.active .material-symbols-outlined {
            color: #070710 !important;
        }

        /* Stat Grid & Highlight Cards */
        .tab-pane {
            display: none;
            animation: fadeIn 0.3s ease forwards;
        }
        .tab-pane.active {
            display: block;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(6px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .highlight-hero-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            margin-bottom: 16px;
        }
        @media(min-width: 768px) {
            .highlight-hero-grid { grid-template-columns: repeat(4, 1fr); }
        }
        .highlight-hero-box {
            background: linear-gradient(135deg, rgba(223,186,115,0.12) 0%, rgba(19,19,38,0.7) 100%);
            border: 1.5px solid rgba(223, 186, 115, 0.3);
            border-radius: var(--radius-md);
            padding: 16px 12px;
            text-align: center;
            position: relative;
            overflow: hidden;
        }
        .highlight-hero-box::after {
            content: '';
            position: absolute;
            top: 0; right: 0; width: 40px; height: 40px;
            background: radial-gradient(circle, rgba(223,186,115,0.2) 0%, transparent 70%);
        }
        .hero-stat-val {
            font-size: 28px;
            font-weight: 900;
            color: var(--gold-light);
            font-family: var(--font-head);
            line-height: 1.1;
        }
        .hero-stat-label {
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-muted);
            margin-top: 4px;
            font-weight: 700;
        }

        .stat-grid-modern {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
        }
        @media(max-width: 600px) {
            .stat-grid-modern { grid-template-columns: repeat(2, 1fr); }
        }
        .stat-box-modern {
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-md);
            padding: 14px 10px;
            text-align: center;
            transition: transform 0.2s, border-color 0.2s;
        }
        .stat-box-modern:hover {
            border-color: var(--border-gold);
            transform: translateY(-2px);
        }
        .stat-box-label {
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.8px;
            font-weight: 600;
        }
        .stat-box-val {
            font-size: 20px;
            font-weight: 800;
            color: var(--text-white);
            margin-top: 4px;
            font-family: var(--font-head);
        }

        .team-card-row {
            display: flex;
            align-items: center;
            gap: 14px;
            padding: 14px;
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-md);
            margin-bottom: 10px;
            transition: all 0.2s;
        }
        .team-card-row:hover {
            border-color: var(--gold-primary);
            background: var(--bg-card-hover);
        }
        .team-avatar-icon {
            width: 44px;
            height: 44px;
            border-radius: 10px;
            background: rgba(223, 186, 115, 0.15);
            border: 1px solid rgba(223, 186, 115, 0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--gold-primary);
        }
    </style>
    <script>
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/sw.js');
      }
    </script>
</head>
<body>
<div class="wrap">
    <div class="topbar">
        <div class="brand">
            <a href="../index.php">
                <img src="../assets/logo.png" alt="Logo" style="height:40px;">
            </a>
        </div>
        <div class="top-actions">
            <a class="btn" href="javascript:history.back()">← Back</a>
        </div>
    </div>
    
    <!-- Player Hero Header -->
    <div class="profile-hero">
        <div class="profile-avatar-wrap">
            <?php if(!empty($playerRow['profile_pic'])): ?>
                <img src="../<?= htmlspecialchars($playerRow['profile_pic']) ?>" alt="<?= htmlspecialchars($pName) ?>">
            <?php else: ?>
                <span class="material-symbols-outlined" style="font-size:64px; color:var(--gold-primary);">account_circle</span>
            <?php endif; ?>
        </div>
        <h1 class="hero-name"><?= htmlspecialchars($pName) ?></h1>
        <div class="profile-badges">
            <?php if(!empty($playerRow['role'])): ?>
                <span class="pill-badge pill-role">
                    <span class="material-symbols-outlined" style="font-size:14px;">sports_cricket</span>
                    <?= htmlspecialchars($playerRow['role']) ?>
                </span>
            <?php endif; ?>
            <?php if(!empty($playerRow['jersey_number'])): ?>
                <span class="pill-badge pill-jersey">#<?= htmlspecialchars($playerRow['jersey_number']) ?></span>
            <?php endif; ?>
            <?php if(!empty($playerRow['is_captain'])): ?>
                <span class="pill-badge pill-captain">👑 Captain</span>
            <?php endif; ?>
            <span class="pill-badge pill-matches">
                <span class="material-symbols-outlined" style="font-size:14px;">stadium</span>
                <?= $totalMatches ?> Matches
            </span>
        </div>
        <?php if(!empty($playerRow['batting_style']) || !empty($playerRow['bowling_style'])): ?>
            <div style="color:var(--text-muted); font-size:13px; margin-top:8px;">
                <?= htmlspecialchars($playerRow['batting_style'] ?? 'Right-hand bat') ?> &bull; <?= htmlspecialchars($playerRow['bowling_style'] ?? 'Right-arm medium') ?>
            </div>
        <?php endif; ?>
    </div>

    <!-- Interactive Touch Tabs -->
    <div class="career-tab-bar" role="tablist">
        <button class="touch-tab-btn active" onclick="switchCareerTab('batting')" id="tab-btn-batting">
            <span class="material-symbols-outlined" style="font-size:18px; color:var(--gold-primary);">sports_cricket</span>
            Batting Career
        </button>
        <button class="touch-tab-btn" onclick="switchCareerTab('bowling')" id="tab-btn-bowling">
            <span class="material-symbols-outlined" style="font-size:18px; color:var(--neon-cyan);">sports_baseball</span>
            Bowling Career
        </button>
        <button class="touch-tab-btn" onclick="switchCareerTab('form')" id="tab-btn-form">
            <span class="material-symbols-outlined" style="font-size:18px; color:var(--neon-purple);">trending_up</span>
            Form Guide
        </button>
        <button class="touch-tab-btn" onclick="switchCareerTab('teams')" id="tab-btn-teams">
            <span class="material-symbols-outlined" style="font-size:18px; color:var(--neon-amber);">shield</span>
            Teams & Awards
        </button>
    </div>

    <!-- 🏏 BATTING CAREER TAB -->
    <div class="tab-pane active" id="pane-batting">
        <!-- Batting Hero Highlights -->
        <div class="highlight-hero-grid">
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--gold-light);"><?= (int)$bStats['runs'] ?></div>
                <div class="hero-stat-label">Total Runs</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-cyan);"><?= (int)$bStats['hs'] ?></div>
                <div class="hero-stat-label">Highest Score</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-green);"><?= $bat_avg ?></div>
                <div class="hero-stat-label">Batting Avg</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-amber);"><?= $bat_sr ?></div>
                <div class="hero-stat-label">Strike Rate</div>
            </div>
        </div>

        <!-- Detailed Batting Breakdown -->
        <div class="card" style="margin-bottom:16px;">
            <h2 style="font-size:16px; margin-bottom:14px; display:flex; align-items:center; gap:8px;">
                <span class="material-symbols-outlined" style="color:var(--gold-primary);">bar_chart</span>
                Detailed Batting Statistics
            </h2>
            <div class="stat-grid-modern">
                <div class="stat-box-modern">
                    <div class="stat-box-label">Matches</div>
                    <div class="stat-box-val"><?= $totalMatches ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Innings</div>
                    <div class="stat-box-val"><?= $innings_count ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Not Outs</div>
                    <div class="stat-box-val"><?= $not_outs ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Balls Faced</div>
                    <div class="stat-box-val"><?= (int)$bStats['balls'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">50s / 100s</div>
                    <div class="stat-box-val" style="color:var(--gold-light);"><?= $fifties ?> / <?= $hundreds ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Fours (4s)</div>
                    <div class="stat-box-val" style="color:var(--neon-cyan);"><?= (int)$bStats['fours'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Sixes (6s)</div>
                    <div class="stat-box-val" style="color:var(--neon-amber);"><?= (int)$bStats['sixes'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Boundary Runs</div>
                    <div class="stat-box-val" style="color:var(--neon-green);">
                        <?= ((int)$bStats['fours'] * 4) + ((int)$bStats['sixes'] * 6) ?>
                    </div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Boundary %</div>
                    <div class="stat-box-val">
                        <?= ($bStats['runs'] > 0) ? round(((((int)$bStats['fours'] * 4) + ((int)$bStats['sixes'] * 6)) / (int)$bStats['runs']) * 100, 1) : 0 ?>%
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- 🎯 BOWLING CAREER TAB -->
    <div class="tab-pane" id="pane-bowling">
        <!-- Bowling Hero Highlights -->
        <div class="highlight-hero-grid">
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-red);"><?= (int)$oStats['wickets'] ?></div>
                <div class="hero-stat-label">Total Wickets</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--gold-light);"><?= $bbi ?></div>
                <div class="hero-stat-label">Best Bowling (BBI)</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-green);"><?= $bowl_econ ?></div>
                <div class="hero-stat-label">Economy Rate</div>
            </div>
            <div class="highlight-hero-box">
                <div class="hero-stat-val" style="color:var(--neon-cyan);"><?= $bowl_avg ?></div>
                <div class="hero-stat-label">Bowling Avg</div>
            </div>
        </div>

        <!-- Detailed Bowling Breakdown -->
        <div class="card" style="margin-bottom:16px;">
            <h2 style="font-size:16px; margin-bottom:14px; display:flex; align-items:center; gap:8px;">
                <span class="material-symbols-outlined" style="color:var(--neon-cyan);">query_stats</span>
                Detailed Bowling Statistics
            </h2>
            <div class="stat-grid-modern">
                <div class="stat-box-modern">
                    <div class="stat-box-label">Matches</div>
                    <div class="stat-box-val"><?= $totalMatches ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Innings Bowled</div>
                    <div class="stat-box-val"><?= count($bowlHist) ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Overs</div>
                    <div class="stat-box-val"><?= round($overs, 1) ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Legal Balls</div>
                    <div class="stat-box-val"><?= (int)$oStats['legal_balls'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Strike Rate</div>
                    <div class="stat-box-val"><?= $bowl_sr ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">3w / 5w Hauls</div>
                    <div class="stat-box-val" style="color:var(--gold-light);"><?= $w3 ?> / <?= $w5 ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Runs Conceded</div>
                    <div class="stat-box-val"><?= (int)$oStats['runs_conceded'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">Wides (WD)</div>
                    <div class="stat-box-val" style="color:var(--neon-amber);"><?= (int)$oStats['wides'] ?></div>
                </div>
                <div class="stat-box-modern">
                    <div class="stat-box-label">No Balls (NB)</div>
                    <div class="stat-box-val" style="color:var(--neon-red);"><?= (int)$oStats['no_balls'] ?></div>
                </div>
            </div>
        </div>
    </div>

    <!-- 📈 FORM GUIDE TAB -->
    <div class="tab-pane" id="pane-form">
        <?php if(count($graphRuns) > 0): ?>
        <div class="card" style="margin-bottom:16px;">
            <h2 style="font-size:16px; margin-bottom:14px; display:flex; align-items:center; gap:8px;">
                <span class="material-symbols-outlined" style="color:var(--neon-purple);">show_chart</span>
                Form Guide (Last 20 Innings)
            </h2>
            <div style="height: 240px; width: 100%;">
                <canvas id="batChart"></canvas>
            </div>
        </div>
        <div class="card" style="margin-bottom:16px;">
            <h2 style="font-size:16px; margin-bottom:14px;">Recent Scores Timeline</h2>
            <div style="display:flex; gap:8px; overflow-x:auto; padding-bottom:6px; scrollbar-width:none;">
                <?php foreach($chartData as $cd): 
                    $r = (int)$cd['runs'];
                    $isOut = ((int)$cd['is_out'] == 1);
                    $badgeBg = ($r >= 50) ? 'rgba(223, 186, 115, 0.25)' : 'rgba(255,255,255,0.05)';
                    $badgeBorder = ($r >= 50) ? 'var(--gold-primary)' : 'var(--border-subtle)';
                    $color = ($r >= 50) ? 'var(--gold-light)' : 'var(--text-white)';
                ?>
                <div style="min-width:65px; padding:10px 8px; border-radius:10px; background:<?= $badgeBg ?>; border:1px solid <?= $badgeBorder ?>; text-align:center;">
                    <div style="font-size:11px; color:var(--text-muted);">M#<?= $cd['id'] ?></div>
                    <div style="font-size:18px; font-weight:800; color:<?= $color ?>; margin-top:2px;">
                        <?= $r ?><?= $isOut ? '' : '*' ?>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
        </div>
        <?php else: ?>
        <div class="card" style="text-align:center; padding:30px 20px;">
            <span class="material-symbols-outlined" style="font-size:48px; color:var(--text-muted);">hourglass_empty</span>
            <div style="margin-top:10px; color:var(--text-muted);">No match innings recorded for this player yet.</div>
        </div>
        <?php endif; ?>
    </div>

    <!-- 🛡️ TEAMS & AWARDS TAB -->
    <div class="tab-pane" id="pane-teams">
        <?php if($momCount > 0): ?>
        <div class="card" style="margin-bottom:16px; border:1px solid rgba(245, 158, 11, 0.4); background: linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(19, 19, 38, 0.8) 100%);">
            <div style="display:flex; align-items:center; gap:16px;">
                <span class="material-symbols-outlined" style="font-size:40px; color:var(--neon-amber);">emoji_events</span>
                <div>
                    <div style="font-size:12px; color:var(--gold-light); text-transform:uppercase; font-weight:700; letter-spacing:1px;">Player Honors</div>
                    <div style="font-size:22px; font-weight:900; color:var(--text-white); font-family:var(--font-head); margin-top:2px;">
                        <?= (int)$momCount ?>x Man of the Match
                    </div>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <div class="card">
            <h2 style="font-size:16px; margin-bottom:14px; display:flex; align-items:center; gap:8px;">
                <span class="material-symbols-outlined" style="color:var(--gold-primary);">groups</span>
                Teams & Tournaments Participated
            </h2>
            <?php if(count($teamsList) > 0): ?>
                <?php foreach($teamsList as $tm): ?>
                <div class="team-card-row">
                    <div class="team-avatar-icon">
                        <span class="material-symbols-outlined"><?= $tm['team_icon'] ?: 'shield' ?></span>
                    </div>
                    <div style="flex:1;">
                        <div style="font-weight:800; font-size:15px; color:var(--text-white); font-family:var(--font-head);">
                            <?= htmlspecialchars($tm['team_name']) ?>
                        </div>
                        <div style="font-size:12px; color:var(--text-muted); margin-top:2px;">
                            🏆 <?= htmlspecialchars($tm['tour_name']) ?>
                        </div>
                    </div>
                </div>
                <?php endforeach; ?>
            <?php else: ?>
                <div style="color:var(--text-muted); padding:10px 0;">No tournament teams associated with this player yet.</div>
            <?php endif; ?>
        </div>
    </div>

</div>

<script>
    function switchCareerTab(tabId) {
        // Toggle tab buttons
        document.querySelectorAll('.touch-tab-btn').forEach(btn => btn.classList.remove('active'));
        const activeBtn = document.getElementById('tab-btn-' + tabId);
        if (activeBtn) activeBtn.classList.add('active');

        // Toggle tab panes
        document.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));
        const activePane = document.getElementById('pane-' + tabId);
        if (activePane) activePane.classList.add('active');
    }

    // Initialize Chart
    const ctx = document.getElementById('batChart');
    if(ctx) {
        new Chart(ctx, {
            type: 'line',
            data: {
                labels: <?= json_encode($graphLabels) ?>,
                datasets: [{
                    label: 'Runs',
                    data: <?= json_encode($graphRuns) ?>,
                    borderColor: '#dfba73',
                    borderWidth: 2.5,
                    tension: 0.35,
                    pointBackgroundColor: <?= json_encode($graphColors) ?>,
                    pointBorderColor: '#070710',
                    pointBorderWidth: 2,
                    pointRadius: 6,
                    fill: true,
                    backgroundColor: 'rgba(223, 186, 115, 0.12)' 
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: { 
                        beginAtZero: true, 
                        grid: { color: 'rgba(255, 255, 255, 0.08)' },
                        ticks: { color: '#94a3b8', font: { family: "'Outfit', sans-serif" } } 
                    },
                    x: { 
                        grid: { display: false },
                        ticks: { color: '#94a3b8', font: { family: "'Outfit', sans-serif" } }
                    }
                }
            }
        });
    }
</script>
</body>
</html>