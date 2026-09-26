<?php
// pages/register_player.php - Dedicated Mobile-First Team Player Registration Screen
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../api/auth.php';

$user = auth_user($pdo);
$teamId = (int)($_GET['team_id'] ?? 0);
$tournamentId = (int)($_GET['tournament_id'] ?? 0);

// Fetch Team info if team_id provided
$team = null;
if ($teamId > 0) {
    $tStmt = $pdo->prepare("SELECT t.*, tr.name as tournament_name, tr.id as tr_id FROM teams t JOIN tournaments tr ON t.tournament_id = tr.id WHERE t.id = ?");
    $tStmt->execute([$teamId]);
    $team = $tStmt->fetch(PDO::FETCH_ASSOC);
    if ($team && $tournamentId <= 0) {
        $tournamentId = (int)$team['tr_id'];
    }
}

// Fetch all tournaments and teams for dropdown selection if no team pre-selected
$allTournaments = $pdo->query("SELECT id, name FROM tournaments ORDER BY id DESC")->fetchAll(PDO::FETCH_ASSOC);
if ($tournamentId <= 0 && count($allTournaments) > 0) {
    $tournamentId = (int)$allTournaments[0]['id'];
}

$allTeams = [];
if ($tournamentId > 0) {
    $tmStmt = $pdo->prepare("SELECT * FROM teams WHERE tournament_id = ? ORDER BY name");
    $tmStmt->execute([$tournamentId]);
    $allTeams = $tmStmt->fetchAll(PDO::FETCH_ASSOC);
    if (!$team && count($allTeams) > 0 && $teamId <= 0) {
        $team = $allTeams[0];
        $teamId = (int)$team['id'];
    }
}

// Fetch existing registered players for this team
$squadPlayers = [];
if ($teamId > 0) {
    $pStmt = $pdo->prepare("SELECT * FROM players WHERE team_id = ? ORDER BY is_captain DESC, id ASC");
    $pStmt->execute([$teamId]);
    $squadPlayers = $pStmt->fetchAll(PDO::FETCH_ASSOC);
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Player Registration - <?= htmlspecialchars($team['name'] ?? 'SB CricScore') ?></title>
  <link rel="stylesheet" href="../style.css?v=<?= time() ?>"/>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <link rel="manifest" href="../manifest.json">
  <link rel="icon" type="image/png" href="../assets/logo.png">
  <meta name="theme-color" content="#070710">

  <style>
    .reg-container {
      max-width: 680px;
      margin: 0 auto;
      padding: 10px 0;
    }
    
    /* TEAM BANNER */
    .team-hero {
      background: linear-gradient(135deg, rgba(223, 186, 115, 0.15) 0%, rgba(19, 19, 38, 0.95) 100%);
      border: 1px solid var(--border-gold);
      border-radius: var(--radius-lg);
      padding: 22px;
      margin-bottom: 20px;
      box-shadow: var(--shadow-main), 0 0 20px rgba(223, 186, 115, 0.2);
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
    }
    
    .team-badge-box {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    
    .team-icon-circle {
      width: 52px;
      height: 52px;
      border-radius: 50%;
      background: rgba(223, 186, 115, 0.18);
      border: 2px solid var(--gold-primary);
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--gold-primary);
      font-size: 28px;
      box-shadow: var(--gold-glow);
    }

    /* AVATAR UPLOADER */
    .avatar-upload-wrap {
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 20px;
    }

    .avatar-preview-box {
      width: 104px;
      height: 104px;
      border-radius: 50%;
      border: 2px dashed var(--gold-primary);
      background: #181830;
      position: relative;
      cursor: pointer;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      overflow: hidden;
      transition: all 0.2s ease;
      box-shadow: 0 4px 15px rgba(0,0,0,0.5);
    }

    .avatar-preview-box:hover {
      border-color: var(--gold-light);
      transform: scale(1.03);
      box-shadow: var(--gold-glow);
    }

    .avatar-preview-box img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: none;
    }

    .avatar-placeholder {
      display: flex;
      flex-direction: column;
      align-items: center;
      color: var(--gold-light);
      font-size: 11px;
      text-align: center;
      padding: 6px;
    }

    /* ROLE SELECTION PILLS */
    .role-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
      margin: 8px 0 16px 0;
    }
    @media (max-width: 480px) {
      .role-grid { grid-template-columns: repeat(2, 1fr); }
    }

    .role-option {
      cursor: pointer;
      text-align: center;
      padding: 10px 8px;
      border-radius: 8px;
      background: #181830;
      border: 1px solid rgba(223, 186, 115, 0.25);
      color: #cbd5e1;
      font-size: 13px;
      font-weight: 700;
      transition: all 0.2s;
      user-select: none;
    }

    .role-option.selected {
      background: var(--gold-primary) !important;
      color: #070710 !important;
      border-color: var(--gold-primary) !important;
      box-shadow: 0 0 14px rgba(223, 186, 115, 0.4);
    }

    /* SQUAD CARDS */
    .squad-card-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 14px;
      background: #181830;
      border: 1px solid rgba(223, 186, 115, 0.2);
      border-radius: var(--radius-sm);
      margin-bottom: 8px;
      transition: background 0.15s;
    }
    .squad-card-item:hover {
      background: #202040;
      border-color: rgba(223, 186, 115, 0.4);
    }

    .player-thumb {
      width: 42px;
      height: 42px;
      border-radius: 50%;
      object-fit: cover;
      border: 1.5px solid var(--gold-primary);
      background: #0e0e1c;
    }
  </style>
</head>
<body>

<div class="wrap">
  <!-- Topbar Header -->
  <div class="topbar">
    <div class="brand">
      <a href="../index.php" style="display:flex; align-items:center; gap:10px; text-decoration:none;">
        <img src="../assets/logo.png" alt="Logo" onerror="this.src='../assets/icon-192.png'">
        <div class="brand-text">
          <span class="brand-name">SB CRICSCORE</span>
          <span class="muted" style="font-size:11px;">SQUAD REGISTRATION</span>
        </div>
      </a>
    </div>
    <div class="right-actions">
      <?php if ($tournamentId > 0): ?>
        <a class="chip" href="tournament.php?id=<?= $tournamentId ?>">
          <span class="material-symbols-outlined" style="font-size:16px;">dashboard</span> Tournament Hub
        </a>
      <?php endif; ?>
      <a class="chip" href="../index.php"><span class="material-symbols-outlined" style="font-size:16px;">home</span> Home</a>
    </div>
  </div>

  <div class="reg-container">
    
    <!-- Team Banner / Switcher -->
    <div class="team-hero">
      <div class="team-badge-box">
        <div class="team-icon-circle">
          <span class="material-symbols-outlined"><?= $team['icon'] ?? 'shield' ?></span>
        </div>
        <div>
          <span style="font-size:11px; text-transform:uppercase; font-weight:800; color:var(--gold-light); letter-spacing:0.5px;">
            <?= htmlspecialchars($team['tournament_name'] ?? 'Tournament Squad') ?>
          </span>
          <h2 style="margin:2px 0 0 0; color:#ffffff; font-size:22px;">
            <?= htmlspecialchars($team['name'] ?? 'Select a Team') ?> 
            <?php if(!empty($team['short_name'])): ?><span style="font-size:14px; color:var(--gold-light);">[<?= htmlspecialchars($team['short_name']) ?>]</span><?php endif; ?>
          </h2>
          <div style="font-size:12px; color:#cbd5e1; margin-top:2px;">
            <span id="squad-counter-badge" style="color:#34d399; font-weight:700;"><?= count($squadPlayers) ?> Player(s)</span> in squad
          </div>
        </div>
      </div>

      <!-- Share Link Action Buttons -->
      <div style="display:flex; gap:8px; flex-wrap:wrap;">
        <button type="button" onclick="shareOnWhatsApp()" style="background:#25D366; color:#ffffff; font-size:12px; padding:8px 14px; border:none; display:inline-flex; align-items:center; gap:6px; box-shadow:0 4px 12px rgba(37,211,102,0.35);">
          <span>📲 Share on WhatsApp</span>
        </button>
        <button type="button" class="btn-secondary" onclick="copyShareLink()" style="font-size:12px; padding:8px 12px;">
          <span class="material-symbols-outlined" style="font-size:15px;">content_copy</span> Copy Link
        </button>
      </div>
    </div>

    <!-- Team Selector if multiple teams exist -->
    <?php if (count($allTeams) > 1): ?>
      <div style="margin-bottom:16px; background:#131326; padding:10px 14px; border-radius:8px; border:1px solid rgba(223,186,115,0.2); display:flex; align-items:center; gap:10px;">
        <label style="font-size:12px; font-weight:700; color:var(--gold-light); white-space:nowrap; margin:0;">Switch Team:</label>
        <select onchange="location.href='register_player.php?tournament_id=<?= $tournamentId ?>&team_id='+this.value" style="margin:0; flex:1; background:#181830;">
          <?php foreach($allTeams as $tm): ?>
            <option value="<?= $tm['id'] ?>" <?= ((int)$tm['id'] === $teamId) ? 'selected' : '' ?>>
              🛡 <?= htmlspecialchars($tm['name']) ?> (<?= htmlspecialchars($tm['short_name'] ?? '') ?>)
            </option>
          <?php endforeach; ?>
        </select>
      </div>
    <?php endif; ?>

    <?php if (!$team): ?>
      <div class="card" style="text-align:center; padding:30px;">
        <h3>No Team Selected</h3>
        <p class="muted">Please select or create a team from Tournament Hub first.</p>
        <a class="btn" href="../index.php">Go to Home</a>
      </div>
    <?php else: ?>

      <!-- PLAYER REGISTRATION CARD -->
      <div class="card" style="margin-bottom:24px;">
        <h3 style="margin-bottom:16px; display:flex; align-items:center; gap:8px;">
          <span class="material-symbols-outlined" style="color:var(--gold-primary);">person_add</span>
          Register New Player
        </h3>

        <form id="regPlayerForm" onsubmit="handlePlayerSubmit(event)">
          <input type="hidden" name="action" value="add">
          <input type="hidden" name="team_id" value="<?= $teamId ?>">

          <!-- Photo Upload Avatar Circle -->
          <div class="avatar-upload-wrap">
            <div class="avatar-preview-box" onclick="document.getElementById('photoInput').click()" title="Click to upload profile photo">
              <img id="avatarPreviewImg" src="" alt="Preview">
              <div id="avatarPlaceholder" class="avatar-placeholder">
                <span class="material-symbols-outlined" style="font-size:32px; margin-bottom:2px;">add_a_photo</span>
                <span>Add Photo</span>
              </div>
            </div>
            <input type="file" id="photoInput" name="photo" accept="image/*" style="display:none;" onchange="previewAvatar(event)">
            <span class="muted" style="font-size:11px; margin-top:6px;">Tap circle to upload player photo (Optional)</span>
          </div>

          <!-- Player Name & Jersey Row -->
          <div style="display:flex; gap:10px; margin-bottom:12px; flex-wrap:wrap;">
            <div style="flex:2; min-width:200px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Player Name *</label>
              <input type="text" name="name" id="playerName" placeholder="e.g. Virat Sharma" required style="margin-top:4px;">
            </div>
            <div style="flex:1; min-width:100px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Jersey #</label>
              <input type="text" name="jersey_number" id="playerJersey" placeholder="e.g. 18" maxlength="4" style="margin-top:4px;">
            </div>
          </div>

          <!-- Playing Role Selector -->
          <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Playing Role</label>
          <input type="hidden" name="role" id="selectedRole" value="BAT">
          <div class="role-grid">
            <div class="role-option selected" data-role="BAT" onclick="selectRole('BAT', this)">🏏 Batsman</div>
            <div class="role-option" data-role="BOWL" onclick="selectRole('BOWL', this)">🎯 Bowler</div>
            <div class="role-option" data-role="ALL" onclick="selectRole('ALL', this)">⚡ All-Rounder</div>
            <div class="role-option" data-role="WK" onclick="selectRole('WK', this)">🧤 Wk-Keeper</div>
          </div>

          <!-- Batting & Bowling Style -->
          <div style="display:flex; gap:10px; margin-bottom:12px; flex-wrap:wrap;">
            <div style="flex:1; min-width:150px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Batting Style</label>
              <select name="batting_style" style="margin-top:4px;">
                <option value="Right Hand Bat">Right Hand Bat (RHB)</option>
                <option value="Left Hand Bat">Left Hand Bat (LHB)</option>
              </select>
            </div>
            <div style="flex:1; min-width:150px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Bowling Style</label>
              <select name="bowling_style" style="margin-top:4px;">
                <option value="Right Arm Medium">Right Arm Medium / Fast</option>
                <option value="Right Arm Off Spin">Right Arm Spin</option>
                <option value="Left Arm Medium">Left Arm Medium / Fast</option>
                <option value="Left Arm Spin">Left Arm Spin</option>
                <option value="None">None (Pure Batsman)</option>
              </select>
            </div>
          </div>

          <!-- Birth Details Row (DOB, TOB, Birth Place) -->
          <div style="display:flex; gap:10px; margin-bottom:12px; flex-wrap:wrap;">
            <div style="flex:1; min-width:140px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">📅 Date of Birth</label>
              <input type="date" name="dob" style="margin-top:4px;">
            </div>
            <div style="flex:1; min-width:110px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">⏰ Birth Time</label>
              <input type="time" name="tob" value="12:00" style="margin-top:4px;">
            </div>
            <div style="flex:1.5; min-width:160px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">📍 Birth Place</label>
              <input type="text" name="pob" placeholder="e.g. Coimbatore, Tamil Nadu" style="margin-top:4px;">
            </div>
          </div>

          <!-- Mobile & Captain Row -->
          <div style="display:flex; gap:12px; align-items:center; margin-bottom:18px; flex-wrap:wrap;">
            <div style="flex:1; min-width:180px;">
              <label class="muted" style="font-size:11.5px; text-transform:uppercase; font-weight:700;">Contact / Mobile #</label>
              <input type="tel" name="mobile" placeholder="e.g. 9876543210" style="margin-top:4px;">
            </div>
            
            <label style="display:flex; align-items:center; gap:8px; background:rgba(223,186,115,0.08); padding:10px 14px; border-radius:8px; border:1px solid rgba(223,186,115,0.25); cursor:pointer; margin-top:16px;">
              <input type="checkbox" name="is_captain" value="1" style="width:20px; height:20px; margin:0;">
              <span style="font-weight:700; color:#f59e0b; font-size:13px;">👑 Team Captain</span>
            </label>
          </div>

          <button id="btnSubmitPlayer" type="submit" style="width:100%; padding:14px; font-size:15px; font-weight:800;">
            ⚡ REGISTER PLAYER TO SQUAD
          </button>
        </form>
      </div>

      <!-- REGISTERED SQUAD LIST -->
      <div class="card">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
          <h2>Registered Squad (<span id="squad-list-count"><?= count($squadPlayers) ?></span>)</h2>
        </div>

        <div id="squad-container">
          <?php if (empty($squadPlayers)): ?>
            <div id="empty-squad-msg" class="muted" style="text-align:center; padding:25px;">
              No players registered for <b><?= htmlspecialchars($team['name']) ?></b> yet.<br>Use the form above to register players!
            </div>
          <?php endif; ?>

          <?php foreach($squadPlayers as $p): ?>
            <div class="squad-card-item" id="player-row-<?= $p['id'] ?>">
              <div style="display:flex; align-items:center; gap:12px;">
                <?php if(!empty($p['profile_pic'])): ?>
                  <img class="player-thumb" src="../<?= htmlspecialchars($p['profile_pic']) ?>" alt="<?= htmlspecialchars($p['name']) ?>">
                <?php else: ?>
                  <div class="player-thumb" style="display:flex; align-items:center; justify-content:center; color:var(--gold-primary); font-weight:800; font-size:14px;">
                    <?= strtoupper(substr($p['name'], 0, 1)) ?>
                  </div>
                <?php endif; ?>

                <div>
                  <div style="display:flex; align-items:center; gap:6px;">
                    <b style="color:#ffffff; font-size:15px;"><?= htmlspecialchars($p['name']) ?></b>
                    <span class="role-pill" style="font-size:11px; padding:1px 6px; border-radius:4px; background:rgba(223,186,115,0.18); color:var(--gold-light); font-weight:700;"><?= htmlspecialchars($p['role']) ?></span>
                    <?php if(!empty($p['jersey_number'])): ?><span style="font-size:12px; color:var(--gold-light); font-weight:700;">#<?= htmlspecialchars($p['jersey_number']) ?></span><?php endif; ?>
                    <?php if(!empty($p['is_captain'])): ?><span style="color:#f59e0b; font-weight:900; font-size:11px; border:1px solid #f59e0b; border-radius:4px; padding:1px 5px; background:rgba(245,158,11,0.15);">👑 C</span><?php endif; ?>
                  </div>
                  <div class="muted" style="font-size:11.5px; margin-top:2px;">
                    <?= htmlspecialchars($p['batting_style'] ?? 'RHB') ?>
                    <?php if(!empty($p['dob'])): ?> &bull; 🎂 <?= htmlspecialchars($p['dob']) ?><?php endif; ?>
                    <?php if(!empty($p['pob'])): ?> &bull; 📍 <?= htmlspecialchars($p['pob']) ?><?php endif; ?>
                    <?php if(!empty($p['mobile'])): ?> &bull; 📞 <?= htmlspecialchars($p['mobile']) ?><?php endif; ?>
                  </div>
                </div>
              </div>

              <button class="icon-btn danger-icon" onclick="deletePlayer(<?= (int)$p['id'] ?>)" title="Remove Player">
                <span class="material-symbols-outlined" style="font-size:16px;">delete</span>
              </button>
            </div>
          <?php endforeach; ?>
        </div>
      </div>

    <?php endif; ?>

  </div>
</div>

<script>
function selectRole(role, el) {
  document.getElementById('selectedRole').value = role;
  document.querySelectorAll('.role-option').forEach(r => r.classList.remove('selected'));
  el.classList.add('selected');
}

function previewAvatar(event) {
  const file = event.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (e) => {
    const img = document.getElementById('avatarPreviewImg');
    const ph = document.getElementById('avatarPlaceholder');
    img.src = e.target.result;
    img.style.display = 'block';
    ph.style.display = 'none';
  };
  reader.readAsDataURL(file);
}

async function handlePlayerSubmit(e) {
  e.preventDefault();
  const form = document.getElementById('regPlayerForm');
  const btn = document.getElementById('btnSubmitPlayer');
  btn.disabled = true;
  btn.innerText = 'Registering Player...';

  try {
    const fd = new FormData(form);
    const res = await fetch('../api/player_register.php', { method: 'POST', body: fd });
    const data = await res.json();

    if (data.ok) {
      // Append player to squad list
      appendPlayerCard(data.player);
      // Reset form
      form.reset();
      document.getElementById('avatarPreviewImg').style.display = 'none';
      document.getElementById('avatarPlaceholder').style.display = 'flex';
      selectRole('BAT', document.querySelector('.role-option[data-role="BAT"]'));
      alert(data.message);
    } else {
      alert(data.error || 'Registration failed.');
    }
  } catch(err) {
    alert('Network error: ' + err.message);
  } finally {
    btn.disabled = false;
    btn.innerText = '⚡ REGISTER PLAYER TO SQUAD';
  }
}

function appendPlayerCard(p) {
  const container = document.getElementById('squad-container');
  const emptyMsg = document.getElementById('empty-squad-msg');
  if (emptyMsg) emptyMsg.remove();

  const thumbHtml = p.profile_pic ? 
    `<img class="player-thumb" src="../${p.profile_pic}" alt="${p.name}">` : 
    `<div class="player-thumb" style="display:flex; align-items:center; justify-content:center; color:var(--gold-primary); font-weight:800; font-size:14px;">${p.name.charAt(0).toUpperCase()}</div>`;

  const capHtml = p.is_captain == 1 ? `<span style="color:#f59e0b; font-weight:900; font-size:11px; border:1px solid #f59e0b; border-radius:4px; padding:1px 5px; background:rgba(245,158,11,0.15);">👑 C</span>` : '';
  const jerseyHtml = p.jersey_number ? `<span style="font-size:12px; color:var(--gold-light); font-weight:700;">#${p.jersey_number}</span>` : '';

  const div = document.createElement('div');
  div.className = 'squad-card-item';
  div.id = `player-row-${p.id}`;
  div.innerHTML = `
    <div style="display:flex; align-items:center; gap:12px;">
      ${thumbHtml}
      <div>
        <div style="display:flex; align-items:center; gap:6px;">
          <b style="color:#ffffff; font-size:15px;">${p.name}</b>
          <span class="role-pill" style="font-size:11px; padding:1px 6px; border-radius:4px; background:rgba(223,186,115,0.18); color:var(--gold-light); font-weight:700;">${p.role || 'BAT'}</span>
          ${jerseyHtml}
          ${capHtml}
        </div>
        <div class="muted" style="font-size:11.5px; margin-top:2px;">
          ${p.batting_style || 'RHB'}
          ${p.dob ? `&bull; 🎂 ${p.dob}` : ''}
          ${p.pob ? `&bull; 📍 ${p.pob}` : ''}
          ${p.mobile ? `&bull; 📞 ${p.mobile}` : ''}
        </div>
      </div>
    </div>
    <button class="icon-btn danger-icon" onclick="deletePlayer(${p.id})" title="Remove Player">
      <span class="material-symbols-outlined" style="font-size:16px;">delete</span>
    </button>
  `;

  container.prepend(div);

  // Update counts
  const countEls = [document.getElementById('squad-list-count'), document.getElementById('squad-counter-badge')];
  const total = container.querySelectorAll('.squad-card-item').length;
  countEls.forEach(el => {
    if (el) el.innerText = `${total} Player(s)`;
  });
}

async function deletePlayer(pid) {
  if (!confirm('Remove this player from squad?')) return;
  try {
    const fd = new FormData();
    fd.append('action', 'delete');
    fd.append('player_id', pid);
    const res = await fetch('../api/player_register.php', { method: 'POST', body: fd });
    const data = await res.json();
    if (data.ok) {
      const row = document.getElementById(`player-row-${pid}`);
      if (row) row.remove();
      const total = document.querySelectorAll('.squad-card-item').length;
      document.getElementById('squad-list-count').innerText = total;
      document.getElementById('squad-counter-badge').innerText = `${total} Player(s)`;
    } else {
      alert(data.error || 'Failed to remove player');
    }
  } catch(e) {
    alert('Error removing player: ' + e.message);
  }
}

function copyShareLink() {
  navigator.clipboard.writeText(location.href).then(() => {
    alert('Squad Registration Link copied to clipboard!\nShare this with team captains or players.');
  }).catch(() => {
    prompt('Copy this link:', location.href);
  });
}

function shareOnWhatsApp() {
  const teamName = <?= json_encode($team['name'] ?? 'Your Team') ?>;
  const tourName = <?= json_encode($team['tournament_name'] ?? 'Tournament') ?>;
  const msg = `🏏 *Squad Registration for ${teamName}* (${tourName})\n\nRegister your details & profile photo here:\n${location.href}`;
  window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(msg)}`, '_blank');
}
</script>
</body>
</html>
