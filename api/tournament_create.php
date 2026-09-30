<?php
// /api/tournament_create.php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login();

function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

function table_columns(PDO $pdo, string $table): array {
  $cols = [];
  try {
    $st = $pdo->query("SHOW COLUMNS FROM `$table`");
    while ($r = $st->fetch(PDO::FETCH_ASSOC)) {
      $cols[$r['Field']] = true;
    }
  } catch (Throwable $e) {}
  return $cols;
}


function json_out(int $code, array $payload){
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($payload);
  exit;
}

// CREATE TOURNAMENT POST
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_POST['_action'])) {
  $name = trim((string)($_POST['name'] ?? ''));
  $type = trim((string)($_POST['type'] ?? 'round_robin'));

  if ($name === '') json_out(400, ['error' => 'Tournament name is required']);
  if (!in_array($type, ['round_robin','knockout'], true)) $type = 'round_robin';

  $win  = (int)($_POST['win_points'] ?? 2);
  $tie  = (int)($_POST['tie_points'] ?? 1);
  $nr   = (int)($_POST['nr_points'] ?? 1);
  $loss = (int)($_POST['loss_points'] ?? 0);
  
  $defOvers = (int)($_POST['default_overs'] ?? 20);
  $defWickets = (int)($_POST['default_wickets'] ?? 10);

  $cols = table_columns($pdo, 'tournaments');

  $state = trim((string)($_POST['state'] ?? 'Tamil Nadu'));
  $district = trim((string)($_POST['district'] ?? 'Coimbatore'));
  $city_area = trim((string)($_POST['city_area'] ?? ''));
  $venue_ground = trim((string)($_POST['venue_ground'] ?? ($_POST['venue_name'] ?? '')));
  $pincode = trim((string)($_POST['pincode'] ?? ''));

  $data = [
    'name' => $name,
    'type' => $type,
    'win_points' => $win,
    'tie_points' => $tie,
    'nr_points' => $nr,
    'loss_points' => $loss,
    'default_overs' => $defOvers,
    'default_wickets' => $defWickets,
    'state' => $state,
    'district' => $district,
    'city_area' => $city_area ?: null,
    'venue_ground' => $venue_ground ?: null,
    'pincode' => $pincode ?: null,
  ];

  $insCols = [];
  $insVals = [];
  $params  = [];

  foreach ($data as $k => $v) {
    if (empty($cols) || isset($cols[$k])) {
      $insCols[] = $k;
      $insVals[] = '?';
      $params[]  = $v;
    }
  }

  try {
    $sql = "INSERT INTO tournaments (" . implode(',', $insCols) . ") VALUES (" . implode(',', $insVals) . ")";
    $st = $pdo->prepare($sql);
    $st->execute($params);
    $tid = (int)$pdo->lastInsertId();
    json_out(200, ['ok' => true, 'id' => $tid]);
  } catch (Throwable $e) {
    json_out(500, ['error' => $e->getMessage()]);
  }
}

// ADD TEAMS POST
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['_action'] ?? '') === 'add_teams') {
  $tid = (int)($_POST['tournament_id'] ?? 0);
  $names = $_POST['teams'] ?? [];

  if ($tid <= 0) {
    header('Location: tournament_create.php?err=' . urlencode('Invalid tournament ID'));
    exit;
  }

  $clean = [];
  if (is_array($names)) {
    foreach ($names as $n) {
      $t = trim((string)$n);
      if ($t !== '') $clean[] = $t;
    }
  }

  $clean = array_values(array_unique($clean));

  if (count($clean) < 2) {
    header('Location: tournament_create.php?id=' . $tid . '&err=' . urlencode('Please add at least 2 unique teams.'));
    exit;
  }

  try {
    $st = $pdo->prepare("INSERT INTO teams (tournament_id, name, short_name, icon) VALUES (?, ?, ?, ?)");
    foreach ($clean as $teamName) {
      $short = strtoupper(substr(preg_replace('/[^A-Za-z0-9]/', '', $teamName), 0, 3));
      if (empty($short)) $short = 'TM';
      try {
        $st->execute([$tid, $teamName, $short, 'shield']);
      } catch (Throwable $e) {}
    }
    header('Location: ../pages/tournament.php?id=' . $tid);
    exit;
  } catch (Throwable $e) {
    header('Location: tournament_create.php?id=' . $tid . '&err=' . urlencode('Error adding teams: ' . $e->getMessage()));
    exit;
  }
}

$id = (int)($_GET['id'] ?? 0);
$err = trim((string)($_GET['err'] ?? ''));

$tournament = null;
$teams = [];

if ($id > 0) {
  $st = $pdo->prepare("SELECT * FROM tournaments WHERE id = ?");
  $st->execute([$id]);
  $tournament = $st->fetch(PDO::FETCH_ASSOC);

  if ($tournament) {
    $st = $pdo->prepare("SELECT * FROM teams WHERE tournament_id = ? ORDER BY name");
    $st->execute([$id]);
    $teams = $st->fetchAll(PDO::FETCH_ASSOC);
  }
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <link rel="stylesheet" href="../style.css?v=<?= time() ?>"/>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <title>Create Tournament - SB CricScore</title>
  <style>
    .two { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
    @media (max-width:650px){ .two{ grid-template-columns:1fr; } }
    .err { background:rgba(244,63,94,.15); border:1px solid rgba(244,63,94,.35); color:#fb7185; padding:12px; border-radius:8px; margin-top:12px; font-size:13.5px; }
    .teamrow { display:flex; gap:10px; margin-top:10px; align-items:center; }
    .teamrow input { flex:1; margin:0; }
  </style>
</head>
<body>
<div class="wrap">
  <div class="topbar">
    <div class="brand">
      <a href="../index.php" style="display:flex; align-items:center; gap:10px; text-decoration:none;">
        <img src="../assets/logo.png" alt="Logo" onerror="this.src='../assets/icon-192.png'">
        <div class="brand-text">
          <span class="brand-name">SB CRICSCORE</span>
          <span class="muted" style="font-size:11px;">TOURNAMENT SETUP</span>
        </div>
      </a>
    </div>
    <div class="right-actions">
      <a class="chip" href="../index.php"><span class="material-symbols-outlined" style="font-size:16px;">home</span> Home</a>
    </div>
  </div>

  <?php if ($err): ?>
    <div class="err"><?= h($err) ?></div>
  <?php endif; ?>

  <?php if (!$tournament): ?>
    <div class="card" style="max-width:640px; margin:0 auto;">
      <h2 style="margin-bottom:18px;">🏆 Create New Tournament</h2>

      <form id="createForm" method="post" action="tournament_create.php">
        <label class="muted" style="font-size:12px; text-transform:uppercase; font-weight:700;">Tournament Name</label>
        <input name="name" placeholder="e.g. Astro Premier League 2026" required autofocus>

        <div style="margin-top:12px;">
          <label class="muted" style="font-size:12px; text-transform:uppercase; font-weight:700;">Tournament Type</label>
          <select name="type">
            <option value="round_robin">🔄 Round Robin (League Table + Knockouts)</option>
            <option value="knockout">⚡ Direct Knockout (Elimination)</option>
          </select>
        </div>

        <div style="margin-top:16px;">
          <label class="muted" style="font-size:12px; text-transform:uppercase; font-weight:700;">Points Rules</label>
          <div class="two" style="margin-top:6px;">
            <div>
              <label class="muted" style="font-size:11px;">Win Points</label>
              <input type="number" name="win_points" value="2" min="0">
            </div>
            <div>
              <label class="muted" style="font-size:11px;">Tie Points</label>
              <input type="number" name="tie_points" value="1" min="0">
            </div>
          </div>
          <div class="two" style="margin-top:8px;">
            <div>
              <label class="muted" style="font-size:11px;">No Result (NR) Points</label>
              <input type="number" name="nr_points" value="1" min="0">
            </div>
            <div>
              <label class="muted" style="font-size:11px;">Loss Points</label>
              <input type="number" name="loss_points" value="0" min="0">
            </div>
          </div>
        </div>

        <div style="margin-top:16px;">
          <label class="muted" style="font-size:12px; text-transform:uppercase; font-weight:700;">Match Defaults</label>
          <div class="two" style="margin-top:6px;">
            <div>
              <label class="muted" style="font-size:11px;">Default Overs</label>
              <input type="number" name="default_overs" value="20" min="1">
            </div>
            <div>
              <label class="muted" style="font-size:11px;">Default Wickets</label>
              <input type="number" name="default_wickets" value="10" min="1">
            </div>
          </div>
        </div>

        <button class="btn" style="width:100%; margin-top:20px;">Create & Add Teams →</button>
      </form>
      <div id="createErr" class="err" style="display:none;"></div>
    </div>

    <script>
      function extractId(data, text){
        if (data && Number(data.id) > 0) return Number(data.id);
        const m = String(text).match(/(\d+)/);
        return m ? Number(m[1]) : 0;
      }

      document.getElementById('createForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const box = document.getElementById('createErr');
        box.style.display='none';
        const fd = new FormData(e.target);
        try {
          const r = await fetch(e.target.action || 'tournament_create.php', { method:'POST', body:fd });
          const text = await r.text();
          let data = null;
          try { data = JSON.parse(text); } catch(_) {}
          
          if(!r.ok){
            box.style.display='block';
            box.textContent = (data && data.error) ? data.error : (r.status + ' Error: ' + (text.length > 100 ? text.substring(0, 100) + '...' : text));
            return;
          }
          const tid = extractId(data, text);
          if(!tid) throw new Error('Could not retrieve tournament ID');
          location.href = 'tournament_create.php?id=' + tid;
        } catch(err){
          box.style.display='block';
          box.textContent = 'Error: ' + err.message;
        }
      });
    </script>

  <?php else: ?>
    <div class="card" style="max-width:640px; margin:0 auto;">
      <h2>Add Teams — <?= h($tournament['name']) ?></h2>
      <p class="muted">Add initial participating team names (Minimum 2 teams), or import directly from AstroCricket later in the Tournament Hub.</p>
      
      <?php if (!empty($teams)): ?>
        <div style="margin:12px 0; padding:10px; background:rgba(223,186,115,0.08); border-radius:8px;">
          <b style="color:var(--accent-gold-light);">Existing Teams:</b> <?= h(implode(', ', array_map(fn($x)=>$x['name'], $teams))) ?>
        </div>
      <?php endif; ?>

      <form method="post" id="teamsForm" style="margin-top:14px;">
        <input type="hidden" name="_action" value="add_teams">
        <input type="hidden" name="tournament_id" value="<?= (int)$tournament['id'] ?>">
        <div id="teamsBox"></div>
        <div id="teamsErr" class="err" style="display:none;"></div>
        
        <div style="display:flex; gap:10px; margin-top:20px; flex-wrap:wrap;">
          <button type="button" class="btn-secondary" onclick="addTeam()">+ Add Team Field</button>
          <button type="submit" class="btn">Save Teams</button>
          <a class="chip" href="../pages/tournament.php?id=<?= (int)$tournament['id'] ?>" style="margin-left:auto; align-self:center;">Skip to Tournament Hub →</a>
        </div>
      </form>
    </div>
    <script>
      const box = document.getElementById('teamsBox');
      function addTeam(v=''){
        const d=document.createElement('div'); d.className='teamrow';
        d.innerHTML=`<input name="teams[]" placeholder="e.g. Astro Warriors" value="${v.replace(/"/g,'&quot;')}"><button type="button" class="icon-btn danger-icon" onclick="this.parentElement.remove()" style="width:36px; height:36px;"><span class="material-symbols-outlined" style="font-size:18px;">delete</span></button>`;
        box.appendChild(d);
      }
      addTeam(''); addTeam('');
      document.getElementById('teamsForm').addEventListener('submit', (e)=>{
        const n = Array.from(document.querySelectorAll('[name="teams[]"]')).map(i=>i.value.trim()).filter(x=>x);
        if(new Set(n).size < 2){ 
          e.preventDefault(); 
          document.getElementById('teamsErr').style.display='block'; 
          document.getElementById('teamsErr').textContent='Please add at least 2 distinct team names.'; 
        }
      });
    </script>
  <?php endif; ?>
</div>
</body>
</html>
