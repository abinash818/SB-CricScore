<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../api/auth.php';
$id = (int)($_GET['id'] ?? 0);
$user = auth_user($pdo);

// Fetch Tournament
$t = $pdo->prepare('SELECT * FROM tournaments WHERE id=?');
$t->execute([$id]);
$tour = $t->fetch(PDO::FETCH_ASSOC);
if (!$tour) die('Tournament not found');

// Fetch Teams
$teamsStmt = $pdo->prepare('SELECT * FROM teams WHERE tournament_id=? ORDER BY group_name ASC, name ASC');
$teamsStmt->execute([$id]);
$teams = $teamsStmt->fetchAll(PDO::FETCH_ASSOC);

// Fetch Players grouped by Team
$playersByTeam = [];
$pStmt = $pdo->prepare("SELECT p.*, t.name as team_name FROM players p JOIN teams t ON p.team_id = t.id WHERE t.tournament_id=? ORDER BY p.name");
$pStmt->execute([$id]);
while($r = $pStmt->fetch(PDO::FETCH_ASSOC)){
    $playersByTeam[$r['team_id']][] = $r;
}

// Fetch teams from other tournaments for 1-click team & squad reuse/cloning
$otherTeamsStmt = $pdo->prepare("
    SELECT t.*, tr.name as tournament_name, 
           (SELECT COUNT(*) FROM players WHERE team_id=t.id) as player_count 
    FROM teams t 
    JOIN tournaments tr ON t.tournament_id = tr.id 
    WHERE t.tournament_id != ? 
    ORDER BY tr.id DESC, t.name ASC
");
$otherTeamsStmt->execute([$id]);
$existingOtherTeams = $otherTeamsStmt->fetchAll(PDO::FETCH_ASSOC);

// Fetch Matches with Winner Info and Date/Time/Stage
$matchesStmt = $pdo->prepare("
    SELECT m.*, 
           ta.name as teamA, ta.short_name as teamA_short, ta.icon as teamA_icon, ta.group_name as teamA_group,
           tb.name as teamB, tb.short_name as teamB_short, tb.icon as teamB_icon, tb.group_name as teamB_group,
           tw.name as winner_name, tw.short_name as winner_short
    FROM matches m 
    JOIN teams ta ON ta.id=m.team_a_id 
    JOIN teams tb ON tb.id=m.team_b_id 
    LEFT JOIN teams tw ON tw.id=m.winner_team_id
    WHERE m.tournament_id=? 
    ORDER BY m.is_final ASC, m.id ASC
");
$matchesStmt->execute([$id]);
$matches = $matchesStmt->fetchAll(PDO::FETCH_ASSOC);

$defOvers = (int)($tour['default_overs'] ?? 20);

// Categorize matches for the Bracket Tree View
$groupAMatches = [];
$groupBMatches = [];
$finalMatches = [];
$otherMatches = [];

foreach($matches as $m) {
    if (!empty($m['is_final']) || strtolower($m['stage'] ?? '') === 'final') {
        $finalMatches[] = $m;
    } elseif ($m['teamA_group'] === 'Group A' || $m['teamB_group'] === 'Group A' || strpos(strtolower($m['stage'] ?? ''), 'group a') !== false) {
        $groupAMatches[] = $m;
    } elseif ($m['teamA_group'] === 'Group B' || $m['teamB_group'] === 'Group B' || strpos(strtolower($m['stage'] ?? ''), 'group b') !== false) {
        $groupBMatches[] = $m;
    } else {
        $otherMatches[] = $m;
    }
}

// If no explicit groups, distribute general matches cleanly across left/right branches
if (empty($groupAMatches) && empty($groupBMatches) && !empty($matches)) {
    if (count($matches) === 1) {
        $finalMatches = $matches;
    } else {
        $nonFinals = array_values(array_filter($matches, fn($x) => empty($x['is_final'])));
        $finals = array_values(array_filter($matches, fn($x) => !empty($x['is_final'])));
        if (empty($finals)) {
            $finals = [array_pop($nonFinals)];
        }
        $finalMatches = $finals;
        $mid = (int)ceil(count($nonFinals) / 2);
        $groupAMatches = array_slice($nonFinals, 0, $mid);
        $groupBMatches = array_slice($nonFinals, $mid);
    }
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title><?= htmlspecialchars($tour['name']) ?> - SB CricScore</title>
  <link rel="stylesheet" href="../style.css?v=<?= time() ?>"/>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <link rel="manifest" href="../manifest.json">
  <link rel="icon" type="image/png" href="../assets/logo.png">
  <meta name="theme-color" content="#070710">

  <style>
    body {
      background-color: #070710 !important;
      color: #ffffff !important;
    }
    .grid-2col {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
    }
    @media (max-width: 900px) {
      .grid-2col { grid-template-columns: 1fr; }
    }
    .form-row {
      display: flex;
      gap: 10px;
      align-items: center;
      margin-bottom: 10px;
    }
    .modal-backdrop {
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(4, 4, 10, 0.9);
      backdrop-filter: blur(12px);
      z-index: 1000;
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    .modal {
      background: #131326;
      border: 1px solid var(--gold-primary);
      box-shadow: 0 20px 50px rgba(0,0,0,0.9), 0 0 25px rgba(223, 186, 115, 0.3);
      border-radius: var(--radius-lg);
      padding: 24px;
      width: 100%;
      max-width: 500px;
      position: relative;
      color: #ffffff;
    }
    .icon-btn {
      background: rgba(255, 255, 255, 0.08) !important;
      border: 1px solid rgba(223, 186, 115, 0.3) !important;
      color: var(--gold-light) !important;
      border-radius: 6px;
      width: 32px;
      height: 32px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      padding: 0;
      box-shadow: none;
      transition: all 0.2s;
    }
    .icon-btn:hover {
      background: var(--gold-primary) !important;
      color: #070710 !important;
      box-shadow: 0 0 12px rgba(223, 186, 115, 0.4);
    }
    .icon-btn.danger-icon:hover {
      background: #f43f5e !important;
      border-color: #f43f5e !important;
      color: #fff !important;
    }
    
    /* FIXTURE ITEM CARD */
    .fixture-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 16px;
      background: #181830 !important;
      border: 1px solid rgba(223, 186, 115, 0.22) !important;
      border-radius: var(--radius-sm);
      margin-bottom: 12px;
      transition: all 0.2s;
      text-decoration: none;
      color: #ffffff !important;
    }
    .fixture-item:hover {
      background: #202042 !important;
      border-color: var(--gold-primary) !important;
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0,0,0,0.5), 0 0 15px rgba(223, 186, 115, 0.2);
    }
    .match-link {
      flex: 1;
      text-decoration: none;
      color: #ffffff !important;
    }

    /* TEAM SQUAD BOX */
    .team-squad-box {
      margin-bottom: 18px;
      background: #16162c !important;
      border-radius: var(--radius-md);
      padding: 16px;
      border: 1px solid rgba(223, 186, 115, 0.25) !important;
      box-shadow: 0 6px 20px rgba(0,0,0,0.4);
    }

    .player-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 9px 8px;
      border-bottom: 1px solid rgba(255,255,255,0.06);
      transition: background 0.15s;
    }
    .player-row:hover {
      background: rgba(223, 186, 115, 0.06);
    }
    .player-row:last-child {
      border-bottom: none;
    }

    .regulars-box {
      display: none;
      background: #101020;
      border: 1px solid rgba(223, 186, 115, 0.3);
      border-radius: 8px;
      padding: 12px;
      margin: 10px 0;
      max-height: 150px;
      overflow-y: auto;
    }
    .reg-chip {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(223, 186, 115, 0.18);
      color: var(--gold-light);
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 12px;
      margin: 4px;
      cursor: pointer;
    }

    /* BRACKET TREE STYLES */
    .bracket-tree-container {
      display: flex;
      justify-content: space-between;
      align-items: stretch;
      gap: 16px;
      overflow-x: auto;
      padding: 20px 12px;
      background: radial-gradient(circle at 50% 50%, rgba(223, 186, 115, 0.08) 0%, rgba(13, 13, 26, 0.95) 100%);
      border: 1px solid rgba(223, 186, 115, 0.28);
      border-radius: var(--radius-lg, 12px);
      box-shadow: 0 10px 35px rgba(0,0,0,0.6), 0 0 20px rgba(223, 186, 115, 0.15);
      min-width: 100%;
    }
    @media (max-width: 900px) {
      .bracket-tree-container {
        flex-direction: column;
      }
    }
    .bracket-column {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 14px;
      min-width: 220px;
    }
    .bracket-col-header {
      text-align: center;
      padding: 6px 12px;
      border-radius: 6px;
      font-weight: 900;
      font-size: 13px;
      letter-spacing: 0.8px;
      text-transform: uppercase;
      margin-bottom: 8px;
    }
    .bracket-col-header.group-a {
      background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%);
      color: #fff;
      box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4);
    }
    .bracket-col-header.group-b {
      background: linear-gradient(135deg, #ec4899 0%, #be185d 100%);
      color: #fff;
      box-shadow: 0 4px 14px rgba(236, 72, 153, 0.4);
    }
    .bracket-col-header.final-header {
      background: var(--gold-gradient);
      color: #070710;
      box-shadow: var(--gold-glow);
    }

    .bracket-center-final {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 10px;
      min-width: 240px;
    }
    .trophy-badge-circle {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      background: var(--gold-gradient);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      color: #070710;
      margin: 0 auto 10px auto;
      box-shadow: 0 0 25px rgba(223, 186, 115, 0.6);
    }

    .bracket-match-node {
      background: #181832;
      border: 1px solid rgba(223, 186, 115, 0.3);
      border-radius: 8px;
      padding: 10px 12px;
      position: relative;
      transition: all 0.2s;
      text-decoration: none;
      color: #ffffff !important;
      display: block;
      box-shadow: 0 4px 12px rgba(0,0,0,0.4);
    }
    .bracket-match-node:hover {
      border-color: var(--gold-primary);
      transform: translateY(-2px);
      box-shadow: 0 6px 18px rgba(223, 186, 115, 0.3);
    }
    .bracket-match-node.completed-node {
      border-color: rgba(16, 185, 129, 0.5);
    }
    .bracket-node-date {
      font-size: 11px;
      font-weight: 800;
      color: var(--gold-light);
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 6px;
      border-bottom: 1px dashed rgba(223, 186, 115, 0.2);
      padding-bottom: 4px;
    }
    .bracket-team-line {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 3px 0;
      font-size: 13.5px;
      font-weight: 700;
    }
    .bracket-team-line.is-winner {
      color: #34d399 !important;
      font-weight: 900;
    }
  </style>
</head>
<body>

<!-- Edit Tournament Modal -->
<div id="modal-edit-tour" class="modal-backdrop">
  <div class="modal">
    <h3 style="color:#ffffff; margin-bottom:12px;">Edit Tournament</h3>
    <input type="hidden" id="edit-tr-id" value="<?= $id ?>">
    <label class="muted">Tournament Name</label>
    <input id="edit-tr-name" value="<?= htmlspecialchars($tour['name']) ?>" style="margin-bottom:20px;">
    <div style="display:flex; gap:10px;">
        <button onclick="saveTournamentEdit()" style="flex:1;">Save</button>
        <button class="danger" onclick="document.getElementById('modal-edit-tour').style.display='none'" style="flex:1;">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit Player Modal -->
<div id="modal-edit-player" class="modal-backdrop">
  <div class="modal">
    <h3 style="color:#ffffff; margin-bottom:12px;">Edit Player</h3>
    <input type="hidden" id="edit-pid">
    <label class="muted">Name</label>
    <input id="edit-name" style="margin-bottom:15px;">
    
    <label class="muted">Move to Team</label>
    <select id="edit-team" style="margin-bottom:15px;">
        <?php foreach($teams as $t): ?><option value="<?= $t['id'] ?>"><?= htmlspecialchars($t['name']) ?></option><?php endforeach; ?>
    </select>
    
    <label style="display:flex; align-items:center; gap:8px; margin-bottom:20px; background:rgba(255,255,255,0.05); padding:10px; border-radius:8px;">
        <input type="checkbox" id="edit-captain" style="width:auto; margin:0;"> 
        <span style="color:#ffffff;">Is Captain?</span>
    </label>
    
    <div style="display:flex; gap:10px;">
        <button onclick="savePlayerEdit()" style="flex:1;">Save</button>
        <button class="danger" onclick="document.getElementById('modal-edit-player').style.display='none'" style="flex:1;">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit Team Modal -->
<div id="modal-edit-team" class="modal-backdrop">
  <div class="modal">
    <h3 style="color:#ffffff; margin-bottom:12px;">Edit Team</h3>
    <input type="hidden" id="edit-tid">
    
    <label class="muted">Icon</label>
    <select id="edit-ticon" style="margin-bottom:10px;">
        <option value="shield">🛡 Shield</option>
        <option value="sports_cricket">🏏 Bat</option>
        <option value="bolt">⚡ Bolt</option>
        <option value="stars">✨ Star</option>
        <option value="pets">🦁 Animal</option>
        <option value="local_fire_department">🔥 Fire</option>
    </select>

    <label class="muted">Team Name</label>
    <input id="edit-tname" style="margin-bottom:10px;">
    
    <label class="muted">Short Name</label>
    <input id="edit-tshort" style="margin-bottom:10px;">

    <label class="muted">Group / Zone</label>
    <select id="edit-tgroup" style="margin-bottom:20px;">
        <option value="">-- No Group --</option>
        <option value="Group A">Group A (Zone A)</option>
        <option value="Group B">Group B (Zone B)</option>
        <option value="Group C">Group C (Zone C)</option>
        <option value="Group D">Group D (Zone D)</option>
    </select>
    
    <div style="display:flex; gap:10px;">
        <button onclick="saveTeamEdit()" style="flex:1;">Save</button>
        <button class="danger" onclick="document.getElementById('modal-edit-team').style.display='none'" style="flex:1;">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit Match Fixture Modal -->
<div id="modal-edit-match" class="modal-backdrop">
  <div class="modal">
    <h3 style="color:#ffffff; margin-bottom:12px;">Edit Match Fixture</h3>
    <input type="hidden" id="edit-m-id">
    
    <label class="muted">Team A</label>
    <select id="edit-m-team-a" style="margin-bottom:10px;">
      <?php foreach($teams as $tm): ?><option value="<?= $tm['id'] ?>"><?= htmlspecialchars($tm['name']) ?><?= !empty($tm['group_name'])?' ('.$tm['group_name'].')':'' ?></option><?php endforeach; ?>
    </select>

    <label class="muted">Team B</label>
    <select id="edit-m-team-b" style="margin-bottom:10px;">
      <?php foreach($teams as $tm): ?><option value="<?= $tm['id'] ?>"><?= htmlspecialchars($tm['name']) ?><?= !empty($tm['group_name'])?' ('.$tm['group_name'].')':'' ?></option><?php endforeach; ?>
    </select>

    <div style="display:flex; gap:10px; margin-bottom:10px;">
      <div style="flex:1;">
        <label class="muted">Match Date</label>
        <input type="date" id="edit-m-date" style="margin:0;">
      </div>
      <div style="flex:1;">
        <label class="muted">Match Time</label>
        <input type="text" id="edit-m-time" placeholder="e.g. 10:30 AM" style="margin:0;">
      </div>
    </div>

    <div style="display:flex; gap:10px; margin-bottom:15px;">
      <div style="flex:1;">
        <label class="muted">Stage / Round</label>
        <select id="edit-m-stage" style="margin:0;">
          <option value="League">League Match</option>
          <option value="Group A">Group A Match</option>
          <option value="Group B">Group B Match</option>
          <option value="Quarterfinal">Quarterfinal</option>
          <option value="Semifinal">Semifinal</option>
          <option value="Final">Grand Final</option>
        </select>
      </div>
      <div style="width:90px;">
        <label class="muted">Overs</label>
        <input type="number" id="edit-m-overs" value="<?= $defOvers ?>" style="margin:0;">
      </div>
    </div>

    <label style="display:flex; align-items:center; gap:8px; margin-bottom:20px; background:rgba(255,255,255,0.05); padding:10px; border-radius:8px;">
        <input type="checkbox" id="edit-m-final" style="width:auto; margin:0;"> 
        <span style="color:#ffffff; font-weight:700;">🏆 Is Grand Final Match?</span>
    </label>

    <div style="display:flex; gap:10px;">
        <button onclick="saveMatchEdit()" style="flex:1;">Save Changes</button>
        <button class="danger" onclick="document.getElementById('modal-edit-match').style.display='none'" style="flex:1;">Cancel</button>
    </div>
  </div>
</div>

<div class="wrap">
  <!-- Topbar Header -->
  <div class="topbar">
    <div class="brand">
      <a href="../index.php" style="display:flex; align-items:center; gap:10px; text-decoration:none;">
        <img src="../assets/logo.png" alt="Logo" onerror="this.src='../assets/icon-192.png'">
        <div class="brand-text">
          <span class="brand-name">SB CRICSCORE</span>
          <span class="muted" style="font-size:11px;">TOURNAMENT HUB</span>
        </div>
      </a>
    </div>
    <div class="right-actions">
      <a class="chip" href="../index.php"><span class="material-symbols-outlined" style="font-size:16px;">home</span> Home</a>
      <a class="chip" href="points.php?id=<?= $id ?>"><span class="material-symbols-outlined" style="font-size:16px;">leaderboard</span> Points Table</a>
      <?php if ($user): ?>
        <a class="chip" href="#" onclick="doLogout()"><span class="material-symbols-outlined" style="font-size:16px;">logout</span> Logout</a>
      <?php else: ?>
        <a class="chip" href="login.php"><span class="material-symbols-outlined" style="font-size:16px;">login</span> Login</a>
      <?php endif; ?>
    </div>
  </div>

  <!-- Tournament Header Title -->
  <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:22px; flex-wrap:wrap; gap:14px;">
    <div style="display:flex; align-items:center; gap:12px;">
      <h1 style="margin:0;"><?= htmlspecialchars($tour['name']) ?></h1>
      <?php if($user): ?>
      <button class="icon-btn" onclick="openEditTournament()" title="Edit Tournament Name">
        <span class="material-symbols-outlined" style="font-size:18px;">edit</span>
      </button>
      <?php endif; ?>
    </div>
    
    <?php if ($user): ?>
    <div style="display:flex; gap:10px; flex-wrap:wrap;">
      <a class="btn" href="register_player.php?tournament_id=<?= $id ?>">
        <span class="material-symbols-outlined" style="font-size:18px;">person_add</span> Register Player
      </a>
      <button type="button" class="btn-secondary" onclick="generateFixtures()">
        <span class="material-symbols-outlined" style="font-size:18px;">calendar_month</span> Generate Fixtures
      </button>
      <button type="button" class="danger" onclick="deleteTournament()">
        <span class="material-symbols-outlined" style="font-size:18px;">delete</span> Delete
      </button>
    </div>
    <?php endif; ?>
  </div>

  <!-- Stats Leaderboard Card -->
  <div class="card">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px; flex-wrap:wrap; gap:10px;">
      <h2>Tournament Stats & Leaderboard</h2>
      <input type="text" id="playerSearch" placeholder="Search player stats..." onkeyup="renderTable()" style="display:none; max-width:240px; margin:0;">
    </div>
    
    <div class="tabs">
      <div class="tab active" onclick="showStat('bat', this)">🏏 Most Runs</div>
      <div class="tab" onclick="showStat('bowl', this)">🎯 Most Wickets</div>
      <div class="tab" onclick="showStat('sixes', this)">💥 Most 6s</div>
      <div class="tab" onclick="showStat('fours', this)">⚡ Most 4s</div>
      <div class="tab" onclick="showStat('all', this)">📋 All Players</div>
      <div class="tab" onclick="showStat('global', this)">🌐 Global Stats</div>
    </div>
    
    <div id="stat-box" style="margin-top:10px;">Loading stats...</div>
  </div>

  <!-- 2-Column Grid: Teams & Matches -->
  <div class="grid-2col">
    
    <!-- Column 1: Teams & Squads -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px; flex-wrap:wrap; gap:8px;">
        <h2>Teams & Squads (<?= count($teams) ?>)</h2>
        <a class="btn" href="register_player.php?tournament_id=<?= $id ?>" style="padding:6px 12px; font-size:12px;">
          <span class="material-symbols-outlined" style="font-size:16px;">person_add</span> Register Player
        </a>
      </div>

      <?php if ($user): ?>
        <?php if (!empty($existingOtherTeams)): ?>
        <!-- Clone Team from Another Tournament -->
        <form id="cloneTeamForm" onsubmit="cloneTeamJS(event)" style="border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:15px; margin-bottom:16px; background:rgba(223,186,115,0.04); padding:10px 12px; border-radius:8px;">
          <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700; color:var(--gold-light);">📋 Reuse Team & Squad from Another Tournament</label>
          <input type="hidden" name="tournament_id" value="<?= $id ?>">
          <input type="hidden" name="action" value="clone">
          <div class="form-row" style="margin-top:6px;">
            <select name="clone_source_team_id" required style="flex:2; margin:0;">
              <option value="">-- Select Existing Team to Clone --</option>
              <?php foreach($existingOtherTeams as $ot): ?>
                <option value="<?= $ot['id'] ?>">
                  🛡 <?= htmlspecialchars($ot['name']) ?> (<?= $ot['player_count'] ?> players) [<?= htmlspecialchars($ot['tournament_name']) ?>]
                </option>
              <?php endforeach; ?>
            </select>
            <button class="btn-secondary" style="margin:0; width:auto; padding:10px 14px; font-size:12px;">⚡ Clone Squad</button>
          </div>
        </form>
        <?php endif; ?>

        <!-- Add Team Form -->
        <form id="addTeamForm" onsubmit="addTeamJS(event)" style="border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:15px; margin-bottom:18px;">
          <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Add New Team</label>
          <input type="hidden" name="tournament_id" value="<?= $id ?>">
          <div class="form-row">
            <select name="icon" style="width:65px; margin:0;">
                <option value="shield">🛡</option>
                <option value="sports_cricket">🏏</option>
                <option value="bolt">⚡</option>
                <option value="stars">✨</option>
                <option value="pets">🦁</option>
                <option value="local_fire_department">🔥</option>
            </select>
            <input type="text" name="names" placeholder="Team Name (e.g. Astro Titans)" required style="flex:2; margin:0;">
            <input type="text" name="short_name" placeholder="Short (AST)" maxlength="4" style="width:85px; margin:0;">
            <select name="group_name" style="width:115px; margin:0;">
                <option value="">No Group</option>
                <option value="Group A" selected>Group A</option>
                <option value="Group B">Group B</option>
                <option value="Group C">Group C</option>
                <option value="Group D">Group D</option>
            </select>
            <button style="margin:0; width:auto; padding:10px 16px;">Add</button>
          </div>
        </form>

        <!-- Add Players Form -->
        <form id="addPlayerForm" onsubmit="addPlayersJS(event)" style="margin-bottom:20px; border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:15px;">
            <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Add Players to Team</label>
            <div class="form-row">
                <select id="sel-team-add" name="team_id" required style="flex:1; margin:0;"><option value="">-- Select Team --</option><?php foreach($teams as $tm): ?><option value="<?= $tm['id'] ?>"><?= htmlspecialchars($tm['name']) ?><?= !empty($tm['group_name']) ? ' ('.htmlspecialchars($tm['group_name']).')' : '' ?></option><?php endforeach; ?></select>
                <button type="button" class="btn-secondary" onclick="toggleRegulars()" style="width:auto; padding:10px 14px; font-size:12px; margin:0;">+ Regulars</button>
            </div>
            
            <div id="regulars-box" class="regulars-box">Loading Regulars...</div>
            
            <div class="form-row" style="align-items:flex-start; margin-top:8px;">
                <textarea name="names" id="p-names" rows="2" placeholder="Player names (one per line)" required style="flex:1; margin:0;"></textarea>
                <label style="display:flex; flex-direction:column; align-items:center; font-size:11px; color:#cbd5e1; padding:4px 8px;">
                    <input type="checkbox" name="is_captain" value="1" style="width:18px; height:18px; margin-bottom:2px;"> 
                    Captain?
                </label>
            </div>
            
            <div class="form-row" style="margin-top:8px;">
                <button class="btn-secondary" style="flex:1; margin:0;">Add to Team</button>
                <button type="button" onclick="saveAsRegular()" style="background:#10b981; color:#fff !important; flex:1; margin:0;">Save Regular</button>
            </div>
        </form>
      <?php endif; ?>

      <!-- Teams List Container -->
      <div id="teams-list-container">
      <?php if(empty($teams)): ?>
        <div style="text-align:center; padding:25px;" class="muted">No teams in this tournament yet. Create one above or import from AstroCricket!</div>
      <?php endif; ?>
      <?php foreach($teams as $tm): ?>
        <div class="team-squad-box" id="team-block-<?= $tm['id'] ?>">
            <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:12px; border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:10px;">
                <div style="display:flex; align-items:center; gap:10px;">
                    <span class="material-symbols-outlined" style="font-size:24px; color:var(--gold-primary);"><?= $tm['icon'] ?? 'shield' ?></span>
                    <div>
                        <div style="font-weight:800; color:#ffffff; font-size:16px; letter-spacing:0.3px; display:flex; align-items:center; gap:6px;">
                            <?= htmlspecialchars($tm['name']) ?>
                            <?php if(!empty($tm['group_name'])): ?>
                                <span style="font-size:10px; background:var(--gold-gradient); color:#070710; padding:1px 6px; border-radius:4px; font-weight:900;"><?= htmlspecialchars($tm['group_name']) ?></span>
                            <?php endif; ?>
                        </div>
                        <div style="font-size:12px; color:var(--gold-light); font-weight:700;"><?= htmlspecialchars($tm['short_name'] ?? '') ?></div>
                    </div>
                </div>
                <div style="display:flex; align-items:center; gap:6px;">
                    <a class="chip" href="register_player.php?tournament_id=<?= $id ?>&team_id=<?= $tm['id'] ?>" style="padding:4px 10px; font-size:11px; background:rgba(223,186,115,0.18);">
                        <span class="material-symbols-outlined" style="font-size:13px;">person_add</span> Register
                    </a>
                    <?php if($user): ?>
                        <button class="icon-btn" onclick="openEditTeam(<?= $tm['id'] ?>, '<?= htmlspecialchars(addslashes($tm['name'])) ?>', '<?= htmlspecialchars($tm['short_name'] ?? '') ?>', '<?= htmlspecialchars($tm['icon'] ?? 'shield') ?>', '<?= htmlspecialchars($tm['group_name'] ?? '') ?>')" title="Edit Team">
                            <span class="material-symbols-outlined" style="font-size:16px;">edit</span>
                        </button>
                        <button class="icon-btn danger-icon" onclick="deleteTeam(<?= $tm['id'] ?>)" title="Delete Team">
                            <span class="material-symbols-outlined" style="font-size:16px;">delete</span>
                        </button>
                    <?php endif; ?>
                </div>
            </div>
            
            <div id="team-players-<?= $tm['id'] ?>">
            <?php if(isset($playersByTeam[$tm['id']]) && count($playersByTeam[$tm['id']]) > 0): ?>
                <?php foreach($playersByTeam[$tm['id']] as $p): ?>
                    <div class="player-row" id="p-row-<?= $p['id'] ?>">
                        <a href="player.php?id=<?= $p['id'] ?>" style="text-decoration:none; color:#ffffff !important; font-size:14.5px; font-weight:700; display:inline-flex; align-items:center; gap:8px;">
                            <?php if(!empty($p['profile_pic'])): ?>
                                <img src="../<?= htmlspecialchars($p['profile_pic']) ?>" alt="" style="width:28px; height:28px; border-radius:50%; object-fit:cover; border:1px solid var(--gold-primary);">
                            <?php else: ?>
                                <div style="width:28px; height:28px; border-radius:50%; background:#181830; border:1px solid var(--gold-primary); display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:800; color:var(--gold-primary);">
                                    <?= strtoupper(substr($p['name'], 0, 1)) ?>
                                </div>
                            <?php endif; ?>
                            <span style="color:#ffffff !important;"><?= htmlspecialchars($p['name']) ?></span>
                            <?php if(!empty($p['role'])): ?><span class="role-pill"><?= htmlspecialchars($p['role']) ?></span><?php endif; ?>
                            <?php if(!empty($p['jersey_number'])): ?><span style="font-size:12px; color:var(--gold-light); font-weight:700;">#<?= htmlspecialchars($p['jersey_number']) ?></span><?php endif; ?>
                            <?php if(!empty($p['is_captain'])): ?><span style="color:#f59e0b; font-weight:900; font-size:11px; border:1px solid #f59e0b; border-radius:4px; padding:1px 5px; background:rgba(245,158,11,0.15);">👑 C</span><?php endif; ?>
                        </a>
                        <?php if($user): ?>
                            <div style="display:flex; align-items:center; gap:4px;">
                                <button class="icon-btn" style="width:26px; height:26px;" onclick="openEditPlayer(<?= $p['id'] ?>, '<?= htmlspecialchars(addslashes($p['name'])) ?>', <?= $tm['id'] ?>, <?= isset($p['is_captain']) ? $p['is_captain'] : 0 ?>)">
                                    <span class="material-symbols-outlined" style="font-size:14px;">edit</span>
                                </button>
                                <button class="icon-btn danger-icon" style="width:26px; height:26px;" onclick="deletePlayer(<?= $p['id'] ?>)">
                                    <span class="material-symbols-outlined" style="font-size:14px;">delete</span>
                                </button>
                            </div>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            <?php else: ?>
                <div class="muted" style="font-size:13px; padding:8px 4px; color:#94a3b8 !important;">No players in this squad yet.</div>
            <?php endif; ?>
            </div>
        </div>
      <?php endforeach; ?>
      </div>
    </div>

    <!-- Column 2: Fixtures & Matches -->
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px; flex-wrap:wrap; gap:10px;">
        <h2>Fixtures & Matches (<?= count($matches) ?>)</h2>
        <div class="view-toggle" style="display:flex; background:#181830; border:1px solid rgba(223,186,115,0.3); border-radius:8px; padding:3px;">
          <button type="button" id="btn-view-list" class="chip active" onclick="switchFixtureView('list')" style="border:none; cursor:pointer; font-size:12px; font-weight:700;">
            <span class="material-symbols-outlined" style="font-size:15px;">list</span> List View
          </button>
          <button type="button" id="btn-view-bracket" class="chip" onclick="switchFixtureView('bracket')" style="border:none; cursor:pointer; font-size:12px; font-weight:700; background:transparent; color:#cbd5e1;">
            <span class="material-symbols-outlined" style="font-size:15px;">account_tree</span> Bracket Tree
          </button>
        </div>
      </div>

      <?php if ($user && count($teams) >= 2): ?>
        <!-- Schedule Match Form -->
        <form method="post" action="../api/match_create.php" onsubmit="return submitForm(event,this, res=>{ location.href='match.php?id='+res.match_id; })" style="margin-bottom:20px; border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:18px;">
            <input type="hidden" name="tournament_id" value="<?= $id ?>">
            <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Schedule New Match</label>
            <div class="form-row">
                <select name="team_a_id" required style="flex:1; margin:0;"><option value="">Team A</option><?php foreach($teams as $tm): ?><option value="<?= (int)$tm['id'] ?>"><?= htmlspecialchars($tm['name']) ?><?= !empty($tm['group_name'])?' ('.$tm['group_name'].')':'' ?></option><?php endforeach; ?></select>
                <div style="padding:0 6px; color:var(--gold-primary); font-weight:900;">VS</div>
                <select name="team_b_id" required style="flex:1; margin:0;"><option value="">Team B</option><?php foreach($teams as $tm): ?><option value="<?= (int)$tm['id'] ?>"><?= htmlspecialchars($tm['name']) ?><?= !empty($tm['group_name'])?' ('.$tm['group_name'].')':'' ?></option><?php endforeach; ?></select>
            </div>
            
            <div class="form-row" style="margin-top:8px;">
                <input type="date" name="match_date" placeholder="Date" style="flex:1; margin:0;">
                <input type="text" name="match_time" placeholder="Time (10:00 AM)" style="flex:1; margin:0;">
                <input type="number" name="overs_limit" value="<?= $defOvers ?>" placeholder="Overs" style="width:75px; margin:0;">
                <label style="display:flex; align-items:center; gap:5px; font-size:12px; color:var(--gold-light); margin-left:6px;">
                    <input type="checkbox" name="is_final" value="1" style="width:auto; margin:0;"> Final
                </label>
            </div>
            <button style="width:100%; margin-top:10px;">START / SCHEDULE MATCH NOW</button>
        </form>
      <?php endif; ?>

      <!-- 1. List View Container -->
      <div id="fixture-list-view">
        <?php if(empty($matches)): ?>
          <div style="text-align:center; padding:30px;" class="muted">No matches scheduled yet. Click "Generate Fixtures" or schedule one above.</div>
        <?php endif; ?>
        <?php foreach($matches as $m): ?>
          <?php
            $mStatus = $m['status'] ?? 'scheduled';
            $isLive = ($mStatus === 'live' || $mStatus === 'awaiting_super_over');
          ?>
          <div class="fixture-item">
            <a class="match-link" href="match.php?id=<?= (int)$m['id'] ?>">
                <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:6px;">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span class="material-symbols-outlined" style="font-size:20px; color:var(--gold-primary);"><?= $m['teamA_icon'] ?: 'shield' ?></span>
                    <b style="color:#ffffff !important; font-size:15px; <?= ($m['winner_team_id'] == $m['team_a_id']) ? 'color:#34d399 !important;' : '' ?>"><?= htmlspecialchars($m['teamA_short'] ?: $m['teamA']) ?></b>
                  </div>
                  <span style="font-size:12px; font-weight:800; color:var(--gold-primary); padding:0 8px;">VS</span>
                  <div style="display:flex; align-items:center; gap:8px;">
                    <b style="color:#ffffff !important; font-size:15px; <?= ($m['winner_team_id'] == $m['team_b_id']) ? 'color:#34d399 !important;' : '' ?>"><?= htmlspecialchars($m['teamB_short'] ?: $m['teamB']) ?></b>
                    <span class="material-symbols-outlined" style="font-size:20px; color:var(--gold-primary);"><?= $m['teamB_icon'] ?: 'shield' ?></span>
                  </div>
                </div>

                <div style="display:flex; align-items:center; justify-content:space-between; margin-top:6px; flex-wrap:wrap; gap:6px;">
                  <div style="display:flex; align-items:center; gap:6px;">
                    <span class="badge <?= $isLive ? 'live' : '' ?>">
                      <?= $mStatus === 'completed' ? '🏁 ' . htmlspecialchars($m['winner_short'] ?: $m['winner_name'] ?: 'Completed') : ($isLive ? '🔴 LIVE' : '📅 Scheduled') ?>
                    </span>
                    <span style="font-size:12px; color:#cbd5e1;">&bull; <?= (int)$m['overs_limit'] ?> ov</span>
                    <?php if(!empty($m['is_final'])): ?><span style="font-size:10px; background:#f59e0b; color:#000; font-weight:900; padding:1px 6px; border-radius:4px;">FINAL</span><?php endif; ?>
                  </div>
                  <?php if(!empty($m['match_date']) || !empty($m['match_time'])): ?>
                    <span style="font-size:11px; color:var(--gold-light); font-weight:700;">
                      📅 <?= htmlspecialchars($m['match_date'] ?? '') ?> <?= !empty($m['match_time']) ? '• ' . htmlspecialchars($m['match_time']) : '' ?>
                    </span>
                  <?php endif; ?>
                </div>
            </a>
            <?php if ($user): ?>
                <div style="display:flex; align-items:center; gap:4px; margin-left:8px;">
                    <button class="icon-btn" onclick="openEditMatch(<?= (int)$m['id'] ?>, <?= (int)$m['team_a_id'] ?>, <?= (int)$m['team_b_id'] ?>, <?= (int)$m['overs_limit'] ?>, '<?= htmlspecialchars(addslashes($m['match_date'] ?? '')) ?>', '<?= htmlspecialchars(addslashes($m['match_time'] ?? '')) ?>', '<?= htmlspecialchars(addslashes($m['stage'] ?? 'League')) ?>', <?= (int)$m['is_final'] ?>)" title="Edit Match Fixture">
                        <span class="material-symbols-outlined" style="font-size:16px;">edit</span>
                    </button>
                    <button class="icon-btn danger-icon" onclick="deleteMatch(<?= (int)$m['id'] ?>)" title="Delete Match">
                        <span class="material-symbols-outlined" style="font-size:16px;">delete</span>
                    </button>
                </div>
            <?php endif; ?>
          </div>
        <?php endforeach; ?>
      </div>

      <!-- 2. Visual Bracket Tree View (போட்டி பிராக்கெட் முறை) -->
      <div id="fixture-bracket-view" style="display:none;">
        <div class="bracket-tree-container">
          
          <!-- LEFT BRANCH: GROUP A / QUARTERFINALS -->
          <div class="bracket-column">
            <div class="bracket-col-header group-a">
              <span class="material-symbols-outlined" style="font-size:15px; vertical-align:middle;">groups</span> Group A Matches
            </div>
            <?php if(empty($groupAMatches)): ?>
              <div class="muted" style="font-size:12px; text-align:center; padding:15px;">No Group A matches.</div>
            <?php endif; ?>
            <?php foreach($groupAMatches as $gm): ?>
              <a href="match.php?id=<?= $gm['id'] ?>" class="bracket-match-node <?= ($gm['status']==='completed')?'completed-node':'' ?>">
                <div class="bracket-node-date">
                  <span>📅 <?= htmlspecialchars($gm['match_date'] ?: 'TBD') ?> <?= !empty($gm['match_time'])?'• '.$gm['match_time']:'' ?></span>
                  <span><?= (int)$gm['overs_limit'] ?> Ov</span>
                </div>
                <div class="bracket-team-line <?= ($gm['winner_team_id']==$gm['team_a_id'])?'is-winner':'' ?>">
                  <span>🛡 <?= htmlspecialchars($gm['teamA_short'] ?: $gm['teamA']) ?></span>
                  <?php if($gm['winner_team_id']==$gm['team_a_id']): ?><span>👑</span><?php endif; ?>
                </div>
                <div class="bracket-team-line <?= ($gm['winner_team_id']==$gm['team_b_id'])?'is-winner':'' ?>">
                  <span>🛡 <?= htmlspecialchars($gm['teamB_short'] ?: $gm['teamB']) ?></span>
                  <?php if($gm['winner_team_id']==$gm['team_b_id']): ?><span>👑</span><?php endif; ?>
                </div>
              </a>
            <?php endforeach; ?>
          </div>

          <!-- CENTER COLUMN: GRAND FINAL & TROPHY -->
          <div class="bracket-center-final">
            <div class="trophy-badge-circle">🏆</div>
            <div class="bracket-col-header final-header">GRAND FINAL</div>

            <?php if(empty($finalMatches)): ?>
              <div class="bracket-match-node" style="text-align:center; min-width:210px; padding:15px;">
                <div class="muted" style="font-size:12px;">Final Match</div>
                <b style="color:var(--gold-light); font-size:14px;">Group A Winner vs Group B Winner</b>
              </div>
            <?php else: ?>
              <?php foreach($finalMatches as $fm): ?>
                <a href="match.php?id=<?= $fm['id'] ?>" class="bracket-match-node <?= ($fm['status']==='completed')?'completed-node':'' ?>" style="min-width:210px; border:2px solid var(--gold-primary); box-shadow:var(--gold-glow);">
                  <div class="bracket-node-date" style="color:var(--gold-primary); font-weight:900;">
                    <span>📅 <?= htmlspecialchars($fm['match_date'] ?: 'GRAND FINAL') ?></span>
                    <span><?= (int)$fm['overs_limit'] ?> Ov</span>
                  </div>
                  <div class="bracket-team-line <?= ($fm['winner_team_id']==$fm['team_a_id'])?'is-winner':'' ?>" style="font-size:15px;">
                    <span>🛡 <b><?= htmlspecialchars($fm['teamA_short'] ?: $fm['teamA']) ?></b></span>
                    <?php if($fm['winner_team_id']==$fm['team_a_id']): ?><span>🏆 WINNER</span><?php endif; ?>
                  </div>
                  <div class="bracket-team-line <?= ($fm['winner_team_id']==$fm['team_b_id'])?'is-winner':'' ?>" style="font-size:15px;">
                    <span>🛡 <b><?= htmlspecialchars($fm['teamB_short'] ?: $fm['teamB']) ?></b></span>
                    <?php if($fm['winner_team_id']==$fm['team_b_id']): ?><span>🏆 WINNER</span><?php endif; ?>
                  </div>
                </a>
              <?php endforeach; ?>
            <?php endif; ?>
          </div>

          <!-- RIGHT BRANCH: GROUP B / QUARTERFINALS -->
          <div class="bracket-column">
            <div class="bracket-col-header group-b">
              <span class="material-symbols-outlined" style="font-size:15px; vertical-align:middle;">groups</span> Group B Matches
            </div>
            <?php if(empty($groupBMatches)): ?>
              <div class="muted" style="font-size:12px; text-align:center; padding:15px;">No Group B matches.</div>
            <?php endif; ?>
            <?php foreach($groupBMatches as $gm): ?>
              <a href="match.php?id=<?= $gm['id'] ?>" class="bracket-match-node <?= ($gm['status']==='completed')?'completed-node':'' ?>">
                <div class="bracket-node-date">
                  <span>📅 <?= htmlspecialchars($gm['match_date'] ?: 'TBD') ?> <?= !empty($gm['match_time'])?'• '.$gm['match_time']:'' ?></span>
                  <span><?= (int)$gm['overs_limit'] ?> Ov</span>
                </div>
                <div class="bracket-team-line <?= ($gm['winner_team_id']==$gm['team_a_id'])?'is-winner':'' ?>">
                  <span>🛡 <?= htmlspecialchars($gm['teamA_short'] ?: $gm['teamA']) ?></span>
                  <?php if($gm['winner_team_id']==$gm['team_a_id']): ?><span>👑</span><?php endif; ?>
                </div>
                <div class="bracket-team-line <?= ($gm['winner_team_id']==$gm['team_b_id'])?'is-winner':'' ?>">
                  <span>🛡 <?= htmlspecialchars($gm['teamB_short'] ?: $gm['teamB']) ?></span>
                  <?php if($gm['winner_team_id']==$gm['team_b_id']): ?><span>👑</span><?php endif; ?>
                </div>
              </a>
            <?php endforeach; ?>
          </div>

        </div>
      </div>

    </div>

  </div>
</div>

<script>
let localStats = null, globalStats = null, currentTab = 'bat', sort = { col:'runs', asc:false };

function switchFixtureView(view) {
    const listBtn = document.getElementById('btn-view-list');
    const bracketBtn = document.getElementById('btn-view-bracket');
    const listView = document.getElementById('fixture-list-view');
    const bracketView = document.getElementById('fixture-bracket-view');

    if (view === 'bracket') {
        listView.style.display = 'none';
        bracketView.style.display = 'block';
        bracketBtn.style.background = 'var(--gold-gradient)';
        bracketBtn.style.color = '#070710';
        listBtn.style.background = 'transparent';
        listBtn.style.color = '#cbd5e1';
    } else {
        bracketView.style.display = 'none';
        listView.style.display = 'block';
        listBtn.style.background = 'var(--gold-gradient)';
        listBtn.style.color = '#070710';
        bracketBtn.style.background = 'transparent';
        bracketBtn.style.color = '#cbd5e1';
    }
}

async function loadStats() {
    try {
      const r = await fetch(`../api/stats.php?tournament_id=<?= $id ?>`);
      localStats = await r.json();
      showStat('bat', document.querySelector('.tab.active'));
    } catch(e) {
      document.getElementById('stat-box').innerHTML = '<div class="muted">Stats not available yet.</div>';
    }
}
async function loadGlobalStats() {
    if(globalStats) return;
    const r = await fetch('../api/stats_global.php');
    globalStats = await r.json();
}
function showStat(type, el) {
    if(el) { document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active')); el.classList.add('active'); }
    currentTab = type;
    const search = document.getElementById('playerSearch');
    if (type === 'all' || type === 'global') {
        search.style.display = 'block'; search.value = '';
        if (type === 'global') loadGlobalStats().then(renderTable); else renderTable();
    } else {
        search.style.display = 'none'; renderCardList(type);
    }
}
function renderCardList(type) {
    const box = document.getElementById('stat-box');
    let data = [];
    if(type==='bat') data=localStats?.batsmen; else if(type==='bowl') data=localStats?.bowlers;
    else if(type==='sixes') data=localStats?.most_sixes; else if(type==='fours') data=localStats?.most_fours;
    if(!data||data.length===0) { box.innerHTML='<div class="muted" style="padding:15px; text-align:center;">No player stats recorded yet.</div>'; return; }
    box.innerHTML = data.map((p,i) => {
        let meta='', val='', cap='';
        if(type==='bat') { if(i===0) cap='orange-cap'; val=`${p.runs} <span style="font-size:11px;color:#cbd5e1">Runs (${p.balls||0}b)</span>`; meta=`Mt:${p.matches} | SR:${p.sr}`; }
        else if(type==='bowl') { if(i===0) cap='purple-cap'; val=`${p.wickets} <span style="font-size:11px;color:#cbd5e1">Wkts</span>`; meta=`Mt:${p.matches} | Ec:${p.econ}`; }
        else { val=p.count; meta=p.team; }
        return `<div class="stat-card ${cap}"><div class="stat-row"><div><div style="font-weight:700;"><a href="player.php?id=${p.id}" style="color:#ffffff;text-decoration:none;">${i+1}. ${p.name}</a></div><div class="stat-meta">${meta}</div></div><div class="stat-val">${val}</div></div></div>`;
    }).join('');
}
function renderTable() {
    const box = document.getElementById('stat-box');
    let d = (currentTab === 'global') ? (globalStats || []) : (localStats?.all_players || []);
    const q = document.getElementById('playerSearch').value.toLowerCase();
    if(q) d = d.filter(p => p.name.toLowerCase().includes(q) || (p.team && p.team.toLowerCase().includes(q)));
    d.sort((a,b) => { let v1=a[sort.col], v2=b[sort.col]; if(sort.col==='name' || sort.col==='team') return sort.asc ? v1.localeCompare(v2) : v2.localeCompare(v1); return sort.asc ? (v1-v2) : (v2-v1); });
    if(d.length===0) { box.innerHTML='<div class="muted" style="padding:15px; text-align:center;">No players match your query.</div>'; return; }
    const th = (k,l) => `<th onclick="sortTable('${k}')" style="cursor:pointer;">${l} ${sort.col===k ? (sort.asc?'↑':'↓') : ''}</th>`;
    let h = `<div class="table-responsive"><table><thead><tr>${th('name','Player')}${currentTab!=='global' ? th('team','Team') : ''}${th('matches','Mat')}${th('runs','Runs')}${th('sr','SR')}${th('fours','4s')}${th('sixes','6s')}${th('wickets','Wkts')}${th('econ','Econ')}</tr></thead><tbody>`;
    d.forEach(p => { h += `<tr><td><a href="player.php?id=${p.id}" style="color:#ffffff;text-decoration:none;"><b>${p.name}</b></a></td>${currentTab!=='global' ? `<td>${p.team}</td>` : ''}<td>${p.matches}</td><td>${p.runs}</td><td>${p.sr}</td><td>${p.fours}</td><td>${p.sixes}</td><td>${p.wickets}</td><td>${p.econ}</td></tr>`; });
    h += `</tbody></table></div>`;
    box.innerHTML = h;
}
function sortTable(key) { if (sort.col === key) sort.asc = !sort.asc; else { sort.col = key; sort.asc = false; if(key==='name'||key==='team') sort.asc=true; } renderTable(); }

// --- Player Management ---
function openEditPlayer(pid, name, tid, isCap) { 
    document.getElementById('edit-pid').value = pid; 
    document.getElementById('edit-name').value = name; 
    document.getElementById('edit-team').value = tid; 
    document.getElementById('edit-captain').checked = (isCap == 1);
    document.getElementById('modal-edit-player').style.display = 'flex'; 
}
async function savePlayerEdit() { 
    const fd = new FormData(); 
    fd.append('player_id', document.getElementById('edit-pid').value); 
    fd.append('name', document.getElementById('edit-name').value); 
    fd.append('team_id', document.getElementById('edit-team').value);
    fd.append('is_captain', document.getElementById('edit-captain').checked ? 1 : 0);
    const r = await fetch('../api/player_edit.php', {method:'POST', body:fd}); 
    if(r.ok) location.reload(); else alert('Failed'); 
}
async function deletePlayer(pid) { 
    if(!confirm("Delete this player?")) return; 
    const fd = new FormData(); fd.append('player_id', pid); 
    const r = await fetch('../api/player_delete.php', {method:'POST', body:fd}); 
    const j = await r.json();
    if(r.ok) document.getElementById('p-row-'+pid).remove(); 
    else alert(j.error || 'Failed to delete'); 
}

// --- Team Management ---
function openEditTeam(tid, name, short, icon, group) { 
    document.getElementById('edit-tid').value = tid; 
    document.getElementById('edit-tname').value = name;
    document.getElementById('edit-tshort').value = short || '';
    document.getElementById('edit-ticon').value = icon || 'shield';
    document.getElementById('edit-tgroup').value = group || '';
    document.getElementById('modal-edit-team').style.display = 'flex'; 
}
async function saveTeamEdit() { 
    const fd = new FormData(); 
    fd.append('team_id', document.getElementById('edit-tid').value); 
    fd.append('name', document.getElementById('edit-tname').value);
    fd.append('short_name', document.getElementById('edit-tshort').value);
    fd.append('icon', document.getElementById('edit-ticon').value);
    fd.append('group_name', document.getElementById('edit-tgroup').value);
    const r = await fetch('../api/team_edit.php', {method:'POST', body:fd}); 
    if(r.ok) location.reload(); else alert('Failed to update team'); 
}
async function deleteTeam(tid) {
    if(!confirm("Delete this Team? WARNING: This will delete all players in the team.")) return;
    const fd = new FormData(); fd.append('team_id', tid);
    const r = await fetch('../api/team_delete.php', {method:'POST', body:fd});
    const j = await r.json();
    if(r.ok) {
        document.getElementById('team-block-'+tid).remove();
        const opts = document.querySelectorAll(`option[value="${tid}"]`);
        opts.forEach(o => o.remove());
    } else {
        alert(j.error || 'Failed to delete team');
    }
}

// --- Match Management ---
function openEditMatch(id, teamAId, teamBId, overs, date, time, stage, isFinal) {
    document.getElementById('edit-m-id').value = id;
    document.getElementById('edit-m-team-a').value = teamAId;
    document.getElementById('edit-m-team-b').value = teamBId;
    document.getElementById('edit-m-overs').value = overs || <?= $defOvers ?>;
    document.getElementById('edit-m-date').value = date || '';
    document.getElementById('edit-m-time').value = time || '';
    document.getElementById('edit-m-stage').value = stage || 'League';
    document.getElementById('edit-m-final').checked = (isFinal == 1);
    document.getElementById('modal-edit-match').style.display = 'flex';
}

async function saveMatchEdit() {
    const fd = new FormData();
    fd.append('match_id', document.getElementById('edit-m-id').value);
    fd.append('team_a_id', document.getElementById('edit-m-team-a').value);
    fd.append('team_b_id', document.getElementById('edit-m-team-b').value);
    fd.append('overs_limit', document.getElementById('edit-m-overs').value);
    fd.append('match_date', document.getElementById('edit-m-date').value);
    fd.append('match_time', document.getElementById('edit-m-time').value);
    fd.append('stage', document.getElementById('edit-m-stage').value);
    fd.append('is_final', document.getElementById('edit-m-final').checked ? 1 : 0);

    try {
        const r = await fetch('../api/match_edit.php', { method: 'POST', body: fd });
        const j = await r.json();
        if (j.ok) {
            location.reload();
        } else {
            alert(j.error || 'Failed to update match');
        }
    } catch(e) {
        alert('Error: ' + e.message);
    }
}

// --- Tournament Edit ---
function openEditTournament() { document.getElementById('modal-edit-tour').style.display = 'flex'; }
async function saveTournamentEdit() {
    const fd = new FormData();
    fd.append('tournament_id', document.getElementById('edit-tr-id').value);
    fd.append('name', document.getElementById('edit-tr-name').value);
    const r = await fetch('../api/tournament_edit.php', {method:'POST', body:fd});
    if(r.ok) location.reload();
    else alert('Failed to update tournament');
}

// --- ADD PLAYERS JS ---
async function addPlayersJS(e) {
    e.preventDefault();
    const form = e.target;
    const btn = form.querySelector('button');
    if (btn) {
        btn.disabled = true;
        btn.innerText = 'Adding Players...';
    }
    try {
        const r = await fetch('../api/player_add.php', {method:'POST', body:new FormData(form)});
        const j = await r.json();
        if(!r.ok) { alert(j.error || 'Failed to add players'); return; }
        if (j.skipped && j.skipped.length > 0) {
            alert(j.message);
        }
        location.reload();
    } catch(err) {
        alert('Error adding players: ' + err.message);
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerText = 'Add Players';
        }
    }
}

// --- Add Team JS ---
async function addTeamJS(e) {
    e.preventDefault();
    const form = e.target;
    const r = await fetch('../api/team_add.php', {method:'POST', body:new FormData(form)});
    const j = await r.json();
    if(!r.ok) { alert(j.error); return; }
    location.reload();
}

// --- Clone Existing Team & Squad JS ---
async function cloneTeamJS(e) {
    e.preventDefault();
    const form = e.target;
    const btn = form.querySelector('button');
    btn.disabled = true;
    btn.innerText = 'Cloning Squad...';
    try {
        const r = await fetch('../api/team_add.php', {method:'POST', body:new FormData(form)});
        const j = await r.json();
        if(!r.ok) { alert(j.error || 'Failed to clone team'); return; }
        alert(j.message);
        location.reload();
    } catch(err) {
        alert('Error cloning team: ' + err.message);
    } finally {
        btn.disabled = false;
        btn.innerText = '⚡ Clone Squad';
    }
}

async function toggleRegulars() { const box = document.getElementById('regulars-box'); if(box.style.display === 'block') { box.style.display='none'; return; } const r = await fetch('../api/regular_players.php?action=list'); const d = await r.json(); box.innerHTML = d.map(p => `
    <div class="reg-chip">
        <span class="reg-name" onclick="addRegName('${p.name}')">${p.name}</span>
        <span class="reg-del" onclick="deleteRegular(${p.id})">&times;</span>
    </div>
`).join('') || '<div class="muted">No regulars saved.</div>'; box.style.display = 'block'; }
function addRegName(name) { const ta = document.getElementById('p-names'); ta.value = ta.value ? ta.value + '\n' + name : name; }
async function saveAsRegular() { const names = document.getElementById('p-names').value.split('\n'); for(let n of names) { if(n.trim()) { const fd = new FormData(); fd.append('action','add'); fd.append('name',n.trim()); await fetch('../api/regular_players.php', {method:'POST', body:fd}); } } alert('Saved!'); toggleRegulars(); }
async function deleteRegular(id) { if(!confirm("Remove from Regulars?")) return; const fd = new FormData(); fd.append('action','delete'); fd.append('id', id); await fetch('../api/regular_players.php', {method:'POST', body:fd}); toggleRegulars(); }

async function doLogout(){ await fetch('../api/logout.php',{method:'POST'}); location.href='../index.php'; }
async function submitForm(e, form, cb){ e.preventDefault(); const r=await fetch(form.action,{method:'POST',body:new FormData(form)}); const j=await r.json(); if(!r.ok){alert(j.error);return;} cb(j); }
async function generateFixtures(){ 
    const o = prompt('Overs per match?', '<?= $defOvers ?>'); 
    if(!o) return;
    const fmt = prompt("Select Fixture Format:\n1 = 🏆 Group Stage (Group A vs Group A, Group B vs Group B)\n2 = 🔄 Single Round Robin (All teams play each other)\n3 = 🔁 Double Round Robin (Home & Away)\n4 = 🥊 Knockout Tournament Bracket", "1"); 
    if(!fmt) return;
    let t = 'group'; 
    if(fmt == '2') t = 'single'; 
    else if(fmt == '3') t = 'double'; 
    else if(fmt == '4') t = 'knockout'; 
    
    const fd = new FormData(); 
    fd.append('tournament_id', '<?= $id ?>'); 
    fd.append('overs_limit', o); 
    fd.append('type', t); 
    try {
        const r = await fetch('../api/fixtures_generate.php', { method: 'POST', body: fd }); 
        const j = await r.json();
        if(j.ok) {
            alert(`Generated ${j.created} match fixtures successfully!`);
            location.reload();
        } else {
            alert(j.error || 'Failed to generate fixtures');
        }
    } catch(err) {
        alert('Error: ' + err.message);
    }
}
async function deleteMatch(mid){ if(confirm("Delete match?")) { const fd=new FormData(); fd.append('match_id',mid); await fetch('../api/match_delete.php',{method:'POST',body:fd}); location.reload(); }}
async function deleteTournament(){ if(confirm("Delete Tournament?")) { const fd=new FormData(); fd.append('tournament_id',<?= $id ?>); await fetch('../api/tournament_delete.php',{method:'POST',body:fd}); location.href='../index.php'; }}

loadStats();
</script>
</body>
</html>