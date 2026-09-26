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
  <title>Points Table & Standings - SB CricScore</title>
  <link rel="manifest" href="../manifest.json">
  <link rel="icon" type="image/png" href="../assets/logo.png">
  <meta name="theme-color" content="#090912">
  <style>
    .group-title-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 14px;
      border-radius: 6px;
      background: var(--gold-gradient);
      color: #070710;
      font-weight: 900;
      font-size: 14px;
      letter-spacing: 0.5px;
      box-shadow: 0 4px 12px rgba(223, 186, 115, 0.3);
      margin-bottom: 12px;
    }
    .group-section {
      margin-bottom: 28px;
    }
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

function renderTableRows(rows) {
  if (!rows || rows.length === 0) {
    return '<tr><td colspan="9" style="text-align:center; padding:20px;" class="muted">No matches played yet.</td></tr>';
  }
  return rows.map((x, idx) => `
    <tr style="${idx < 2 ? 'background:rgba(223,186,115,0.06);' : ''}">
      <td style="font-weight:700; color:var(--accent-gold);">${idx + 1}</td>
      <td>
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="material-symbols-outlined" style="font-size:18px; color:var(--accent-gold);">${x.icon || 'shield'}</span>
          <b style="color:#ffffff;">${escapeHtml(x.team)}</b>
          ${x.group_name ? `<span style="font-size:10px; background:rgba(223,186,115,0.15); color:var(--accent-gold-light); padding:1px 6px; border-radius:4px; font-weight:700;">${escapeHtml(x.group_name)}</span>` : ''}
        </div>
      </td>
      <td style="text-align:center;">${x.P}</td>
      <td style="text-align:center; color:#34d399; font-weight:700;">${x.W}</td>
      <td style="text-align:center; color:#fb7185;">${x.L}</td>
      <td style="text-align:center;">${x.T}</td>
      <td style="text-align:center;">${x.NR}</td>
      <td style="text-align:center; font-family:monospace; font-size:13px; color:${x.NRR >= 0 ? '#34d399' : '#fb7185'}">${Number(x.NRR) > 0 ? '+' : ''}${Number(x.NRR).toFixed(3)}</td>
      <td style="text-align:center; font-weight:900; font-size:16px; color:var(--accent-gold-light);">${x.Pts}</td>
    </tr>
  `).join('');
}

function renderTableMarkup(rows, titleHtml = '') {
  return `
    <div class="group-section">
      ${titleHtml}
      <div class="table-responsive">
        <table>
          <thead>
            <tr>
              <th style="width:40px;">#</th>
              <th>Team</th>
              <th style="text-align:center;">P</th>
              <th style="text-align:center;">W</th>
              <th style="text-align:center;">L</th>
              <th style="text-align:center;">T</th>
              <th style="text-align:center;">NR</th>
              <th style="text-align:center;">NRR</th>
              <th style="text-align:center; color:var(--accent-gold);">PTS</th>
            </tr>
          </thead>
          <tbody>
            ${renderTableRows(rows)}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

async function load(){
  try {
    const r = await fetch(`../api/points_table.php?tournament_id=${tid}`);
    const j = await r.json();
    if(!r.ok){ document.getElementById('view').innerHTML = `<div style="color:#fb7185;">${j.error || 'Error loading points table'}</div>`; return; }

    const t = j.tournament;
    const rows = j.table || [];
    const hasGroups = j.has_groups && j.groups && Object.keys(j.groups).length > 0;

    let tablesHtml = '';

    if (hasGroups) {
      for (const [groupName, groupRows] of Object.entries(j.groups)) {
        tablesHtml += renderTableMarkup(groupRows, `<div class="group-title-badge"><span class="material-symbols-outlined" style="font-size:16px;">groups</span> ${escapeHtml(groupName)}</div>`);
      }
    } else {
      tablesHtml = renderTableMarkup(rows);
    }

    const html = `
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; flex-wrap:wrap; gap:10px; border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:14px;">
        <div>
          <h2 style="margin:0 0 4px 0; color:#fff;">${escapeHtml(t.name)}</h2>
          <span class="muted" style="font-size:12px;">Format: <b style="color:var(--accent-gold); text-transform:uppercase;">${t.type}</b></span>
        </div>
        <div class="muted" style="font-size:12px;">Win = <b style="color:#34d399;">${t.win_points}</b> pts &bull; Tie = <b style="color:#fbbf24;">${t.tie_points}</b> pts &bull; NR = <b>${t.nr_points}</b> pts</div>
      </div>
      ${tablesHtml}
    `;
    document.getElementById('view').innerHTML = html;
  } catch(e) {
    document.getElementById('view').innerHTML = `<div style="color:#fb7185;">Failed to load points table.</div>`;
  }
}

function escapeHtml(s){
  return String(s||'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
}
load();
</script>
</body>
</html>
