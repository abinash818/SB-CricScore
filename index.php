<?php
require_once __DIR__ . '/db.php';

$user = null;
if (file_exists(__DIR__ . '/api/auth.php')) {
  require_once __DIR__ . '/api/auth.php';
  if (function_exists('auth_user')) $user = auth_user($pdo);
}

function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

$tournaments = $pdo->query("SELECT id, name FROM tournaments ORDER BY id DESC")->fetchAll(PDO::FETCH_ASSOC);

$selectedTid = (int)($_GET['tournament_id'] ?? 0);
if ($selectedTid <= 0 && count($tournaments) > 0) $selectedTid = (int)$tournaments[0]['id'];

$tab = strtolower(trim((string)($_GET['tab'] ?? 'all')));
if (!in_array($tab, ['all','live','completed'], true)) $tab = 'all';

$matches = [];
if ($selectedTid > 0) {
  $sql = "
    SELECT m.*, ta.name AS team_a_name, tb.name AS team_b_name,
           ta.short_name AS team_a_short, tb.short_name AS team_b_short,
           ta.icon AS team_a_icon, tb.icon AS team_b_icon
    FROM matches m
    JOIN teams ta ON ta.id = m.team_a_id
    JOIN teams tb ON tb.id = m.team_b_id
    WHERE m.tournament_id = ?
    ORDER BY
      CASE m.status
        WHEN 'live' THEN 0
        WHEN 'awaiting_super_over' THEN 1
        WHEN 'completed' THEN 2
        ELSE 3
      END,
      m.id DESC
  ";
  $st = $pdo->prepare($sql);
  $st->execute([$selectedTid]);
  $matches = $st->fetchAll(PDO::FETCH_ASSOC);

  if ($tab === 'live') {
    $matches = array_values(array_filter($matches, fn($m) => $m['status'] === 'live' || $m['status'] === 'awaiting_super_over'));
  } elseif ($tab === 'completed') {
    $matches = array_values(array_filter($matches, fn($m) => $m['status'] === 'completed'));
  }
}

function result_text($m){
  if (($m['status'] ?? '') !== 'completed') return '';
  $rt = $m['result_type'] ?? null;
  if ($rt === 'tie') return 'MATCH TIED';
  if ($rt === 'nr')  return 'NO RESULT';
  if ($rt === 'A')   return h($m['team_a_name']) . ' WON';
  if ($rt === 'B')   return h($m['team_b_name']) . ' WON';
  return 'COMPLETED';
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>SB CricScore LIVE - Tournament & Match Center</title>
  <link rel="stylesheet" href="style.css?v=<?= time() ?>"/>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <link rel="manifest" href="manifest.json">
  <link rel="icon" type="image/png" href="assets/logo.png">
  <meta name="theme-color" content="#070710">

  <style>
    .grid-matches { 
      display: grid; 
      grid-template-columns: repeat(3, 1fr); 
      gap: 18px; 
      margin-top: 18px; 
    }
    @media (max-width: 950px){ .grid-matches { grid-template-columns: repeat(2, 1fr); } }
    @media (max-width: 620px){ .grid-matches { grid-template-columns: 1fr; } }

    .hero-banner {
      background: linear-gradient(135deg, rgba(223, 186, 115, 0.12) 0%, rgba(18, 18, 34, 0.9) 100%);
      border: 1px solid var(--card-border);
      border-radius: var(--border-radius-lg);
      padding: 24px;
      margin-bottom: 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
    }
  </style>

  <script>
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').catch((err) => console.log('SW Registration Failed', err));
    }
  </script>
</head>
<body>

<div class="home-wrap">
  <!-- Topbar Header -->
  <div class="topbar">
    <div class="brand">
      <a href="index.php" style="display:flex; align-items:center; gap:12px; text-decoration:none;">
        <img src="assets/logo.png" alt="Logo" onerror="this.src='assets/icon-192.png'">
        <div class="brand-text">
          <span class="brand-name">SB CRICSCORE</span>
          <span class="muted" style="font-size:11px;">TOURNAMENT & MATCH ENGINE</span>
        </div>
      </a>
    </div>
    <div class="right-actions">
      <a class="chip" href="pages/players.php"><span class="material-symbols-outlined" style="font-size:16px;">public</span> Global Stats</a>
      <?php if ($user): ?>
        <a class="chip" href="pages/commentary_manager.php"><span class="material-symbols-outlined" style="font-size:16px;">mic</span> Commentary</a>
        <a class="btn" href="api/tournament_create.php" style="padding:7px 14px; font-size:12px;">+ Tournament</a>
        <a class="chip" href="pages/settings.php"><span class="material-symbols-outlined" style="font-size:16px;">settings</span> Settings</a>
        <a class="chip" href="#" id="logoutBtn" style="color:#fb7185;"><span class="material-symbols-outlined" style="font-size:16px;">logout</span> Logout</a>
      <?php else: ?>
        <a class="btn" href="pages/login.php" style="padding:7px 16px; font-size:12px;">Admin Login</a>
      <?php endif; ?>
    </div>
  </div>

  <!-- Tournament Selection & Quick Action Bar -->
  <div class="card">
    <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:14px;">
      <div style="flex:1; min-width:240px;">
        <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Active Tournament</label>
        <select id="tournamentSel" style="margin:4px 0 0 0;">
          <?php if (count($tournaments) === 0): ?>
            <option value="">No tournaments found</option>
          <?php else: ?>
            <?php foreach($tournaments as $t): ?>
              <option value="<?= (int)$t['id'] ?>" <?= ((int)$t['id'] === $selectedTid) ? 'selected' : '' ?>>
                🏏 <?= h($t['name']) ?>
              </option>
            <?php endforeach; ?>
          <?php endif; ?>
        </select>
      </div>

      <?php if ($selectedTid > 0): ?>
        <div style="display:flex; gap:10px; flex-wrap:wrap; align-items:flex-end;">
            <a class="btn" href="pages/tournament.php?id=<?= (int)$selectedTid ?>">
              <span class="material-symbols-outlined" style="font-size:18px;">dashboard</span> Tournament Hub
            </a>
            <a class="btn-secondary" href="pages/points.php?id=<?= (int)$selectedTid ?>">
              <span class="material-symbols-outlined" style="font-size:18px;">leaderboard</span> Points Table
            </a>
        </div>
      <?php endif; ?>
    </div>

    <!-- Match Status Tabs -->
    <div class="tabs" style="margin-top:20px;">
      <a class="tab <?= $tab==='all'?'active':'' ?>" href="?tournament_id=<?= (int)$selectedTid ?>&tab=all">All Matches (<?= count($matches) ?>)</a>
      <a class="tab <?= $tab==='live'?'active':'' ?>" href="?tournament_id=<?= (int)$selectedTid ?>&tab=live">🔴 Live Matches</a>
      <a class="tab <?= $tab==='completed'?'active':'' ?>" href="?tournament_id=<?= (int)$selectedTid ?>&tab=completed">🏁 Completed</a>
    </div>
  </div>

  <?php if ($selectedTid <= 0): ?>
    <div class="card" style="text-align:center; padding:40px;">
      <span class="material-symbols-outlined" style="font-size:48px; color:var(--gold-primary);">sports_cricket</span>
      <h3 style="margin-top:10px;">No Tournaments Created Yet</h3>
      <p class="muted">Login and click <b>+ Tournament</b> to start managing local or league tournaments.</p>
      <?php if($user): ?>
        <a class="btn" href="api/tournament_create.php" style="margin-top:15px;">+ Create Your First Tournament</a>
      <?php endif; ?>
    </div>
  <?php else: ?>
    <!-- Matches Grid -->
    <div class="grid-matches">
      <?php if (count($matches) === 0): ?>
        <div class="card" style="grid-column:1/-1; text-align:center; padding:35px;">
          <span class="material-symbols-outlined" style="font-size:40px; color:var(--text-muted);">event_busy</span>
          <h4 style="margin-top:8px; color:var(--text-muted);">No Matches Found</h4>
          <div class="muted">No matches scheduled in this category yet.</div>
          <?php if ($user): ?>
            <a class="btn-secondary" href="pages/tournament.php?id=<?= (int)$selectedTid ?>" style="margin-top:15px;">Schedule Match in Tournament Hub</a>
          <?php endif; ?>
        </div>
      <?php else: ?>
        <?php foreach($matches as $m): ?>
          <?php
            $status = $m['status'] ?? 'scheduled';
            $isLive = ($status === 'live' || $status === 'awaiting_super_over');
            $badgeText = strtoupper($status);
            if ($status === 'awaiting_super_over') $badgeText = 'TIED (SUPER OVER)';
            $res = result_text($m);
          ?>
          <a class="match-card <?= $isLive ? 'is-live' : '' ?>" href="pages/match.php?id=<?= (int)$m['id'] ?>">
            <div class="match-head">
              <span class="badge <?= $isLive ? 'live' : '' ?>">
                <?= h($badgeText) ?>
              </span>
              <span class="muted" style="font-size:11.5px; font-weight:700;">#MATCH <?= (int)$m['id'] ?></span>
            </div>

            <div class="teams">
              <div style="display:flex; align-items:center; gap:6px;">
                <span class="material-symbols-outlined" style="font-size:18px; color:var(--gold-primary);"><?= $m['team_a_icon'] ?: 'shield' ?></span>
                <span><?= h($m['team_a_short'] ?: $m['team_a_name']) ?></span>
              </div>
              <span class="muted" style="font-size:12px; font-weight:400; padding:0 4px;">vs</span>
              <div style="display:flex; align-items:center; gap:6px;">
                <span><?= h($m['team_b_short'] ?: $m['team_b_name']) ?></span>
                <span class="material-symbols-outlined" style="font-size:18px; color:var(--gold-primary);"><?= $m['team_b_icon'] ?: 'shield' ?></span>
              </div>
            </div>

            <div class="muted" style="font-size:12px; margin-top:4px;">
              🏏 <?= (int)($m['overs_limit'] ?? 0) ?> Overs Limit
              <?php if (!empty($m['is_final'])): ?> • <b style="color:#f59e0b;">FINAL</b><?php endif; ?>
              <?php if (!empty($m['super_over'])): ?> • <b style="color:#a855f7;">Super Over</b><?php endif; ?>
            </div>

            <?php if ($res !== ''): ?>
              <div class="res"><?= h($res) ?></div>
            <?php else: ?>
              <div style="margin-top:10px; font-size:12.5px; color:var(--gold-light); font-weight:600; text-align:center;">
                <?= $isLive ? '🔴 Watch Ball-by-Ball Live' : '📅 Click to view match & score' ?>
              </div>
            <?php endif; ?>
          </a>
        <?php endforeach; ?>
      <?php endif; ?>
    </div>
  <?php endif; ?>
</div>

<script>
  const sel = document.getElementById('tournamentSel');
  if (sel) {
    sel.addEventListener('change', () => {
      const tid = sel.value || '';
      const tab = <?= json_encode($tab) ?>;
      if (!tid) return;
      location.href = `?tournament_id=${encodeURIComponent(tid)}&tab=${encodeURIComponent(tab)}`;
    });
  }

  const logoutBtn = document.getElementById('logoutBtn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async (e) => {
      e.preventDefault();
      try { await fetch('api/logout.php', { method: 'POST', credentials:'same-origin' }); } catch(e){}
      location.href = 'index.php';
    });
  }
</script>
</body>
</html>