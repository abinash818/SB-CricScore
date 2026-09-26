<?php
$id = (int)($_GET['id'] ?? 0);
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <link rel="stylesheet" href="../style.css?v=<?= time() ?>"/>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <title>Points Table - SB CricScore</title>
  <link rel="manifest" href="../manifest.json">
  <link rel="icon" type="image/png" href="../assets/logo.png">
  <meta name="theme-color" content="#090912">
</head>
<body>
<div class="wrap">
  <div class="topbar">
    <div class="brand">
      <a href="../index.php" style="display:flex; align-items:center; gap:10px; text-decoration:none;">
        <img src="../assets/logo.png" alt="Logo" onerror="this.src='../assets/icon-192.png'">
        <div class="brand-text">
          <span class="brand-name">SB CRICSCORE</span>
          <span class="muted" style="font-size:11px;">TOURNAMENT STANDINGS</span>
        </div>
      </a>
    </div>
    <div class="right-actions">
      <a class="chip" href="tournament.php?id=<?= $id ?>"><span class="material-symbols-outlined" style="font-size:16px;">arrow_back</span> Back to Tournament</a>
      <a class="chip" href="../index.php"><span class="material-symbols-outlined" style="font-size:16px;">home</span> Home</a>
    </div>
  </div>

  <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:18px;">
    <h1>Tournament Points Table</h1>
  </div>

  <div id="view" class="card">
    <div style="text-align:center; padding:30px;" class="muted">Loading tournament standings...</div>
  </div>
</div>

<script>
const tid = <?= $id ?>;

async function load(){
  try {
    const r = await fetch(`../api/points_table.php?tournament_id=${tid}`);
    const j = await r.json();
    if(!r.ok){ document.getElementById('view').innerHTML = `<div style="color:#fb7185;">${j.error || 'Error loading points table'}</div>`; return; }

    const t = j.tournament;
    const rows = j.table || [];

    const html = `
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px; flex-wrap:wrap; gap:10px;">
        <h2 style="margin:0;">${escapeHtml(t.name)}</h2>
        <div class="muted" style="font-size:12px;">Type: <b style="color:var(--accent-gold); text-transform:uppercase;">${t.type}</b> &bull; Win=${t.win_points} pts | Tie=${t.tie_points} pts | NR=${t.nr_points} pts</div>
      </div>
      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:40px;">#</th>
              <th>Team</th>
              <th style="text-align:center;">Played</th>
              <th style="text-align:center;">Won</th>
              <th style="text-align:center;">Lost</th>
              <th style="text-align:center;">Tied</th>
              <th style="text-align:center;">NR</th>
              <th style="text-align:center;">NRR</th>
              <th style="text-align:center; color:var(--accent-gold);">Points</th>
            </tr>
          </thead>
          <tbody>
            ${rows.length === 0 ? '<tr><td colspan="9" style="text-align:center; padding:20px;" class="muted">No matches played yet in this tournament.</td></tr>' : ''}
            ${rows.map((x, idx)=>`
              <tr style="${idx < 2 ? 'background:rgba(223,186,115,0.06);' : ''}">
                <td style="font-weight:700; color:var(--accent-gold);">${idx + 1}</td>
                <td><b style="color:#ffffff;">${escapeHtml(x.team)}</b></td>
                <td style="text-align:center;">${x.P}</td>
                <td style="text-align:center; color:#34d399; font-weight:700;">${x.W}</td>
                <td style="text-align:center; color:#fb7185;">${x.L}</td>
                <td style="text-align:center;">${x.T}</td>
                <td style="text-align:center;">${x.NR}</td>
                <td style="text-align:center; font-family:monospace; font-size:13px;">${Number(x.NRR).toFixed(3)}</td>
                <td style="text-align:center; font-weight:800; font-size:16px; color:var(--accent-gold);">${x.Pts}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
    document.getElementById('view').innerHTML = html;
  } catch(e) {
    document.getElementById('view').innerHTML = `<div style="color:#fb7185;">Failed to load points table.</div>`;
  }
}
function escapeHtml(s){
  return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
}
load();
</script>
</body>
</html>
