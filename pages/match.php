<?php
ob_start();
require_once __DIR__ . '/../api/auth.php';
require_once __DIR__ . '/../db.php';
$id = (int)($_GET['id'] ?? 0);
$user = auth_user($pdo);
$canEdit = $user ? true : false;
?>
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
  <link rel="stylesheet" href="../style.css?v=<?= time() ?>"/>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0" />
  <title>Match Center - SB CricScore</title>
  <style>
    /* STICKY HEADER */
    .sticky-header { 
        position: fixed; top: 0; left: 0; right: 0; 
        background: rgba(18, 18, 34, 0.95); backdrop-filter: blur(16px);
        border-bottom: 1px solid var(--accent-gold); 
        padding: 10px 18px; z-index: 999; 
        display: flex; align-items: center; justify-content: space-between; 
        transform: translateY(-120%); transition: transform 0.3s ease; 
        box-shadow: 0 4px 20px rgba(0,0,0,0.5); 
    }
    .sticky-header.visible { transform: translateY(0); }
    .sticky-left { display: flex; flex-direction: column; }
    .sticky-team { font-size: 11px; font-weight: 800; color: var(--accent-gold-light); text-transform: uppercase; letter-spacing: 0.5px; }
    .sticky-score { font-size: 22px; font-weight: 900; color: #fff; line-height: 1; font-family: var(--font-heading); }
    .sticky-overs { font-size: 14px; font-weight: 600; color: var(--accent-gold); }
    .sticky-req { font-size: 12px; font-weight: 700; color: #fb7185; background: rgba(244,63,94,0.15); padding:3px 8px; border-radius:4px; border:1px solid rgba(244,63,94,0.4); }
    
    /* SCORE DISPLAY */
    .score-display { 
        background: var(--card-bg); 
        backdrop-filter: blur(16px);
        border: 1px solid var(--card-border); 
        border-radius: var(--border-radius); 
        padding: 24px; 
        position: relative; 
        box-shadow: var(--shadow-card);
        margin-bottom: 20px;
    }
    .score-big { font-size: 46px; font-weight: 900; font-family: var(--font-heading); color: var(--accent-gold-light); letter-spacing: -1px; }
    
    /* TEAM STICKER */
    .team-sticker {
        background: var(--gold-gradient); color: #090912;
        padding: 4px 14px; border-radius: 6px;
        font-weight: 900; text-transform: uppercase;
        font-size: 13.5px; letter-spacing: 0.8px;
        display: inline-block;
        box-shadow: 0 4px 12px rgba(223, 186, 115, 0.35);
    }

    /* SCORER KEYPAD */
    .scorer-grid { display: grid; grid-template-columns: repeat(6, 1fr); gap: 8px; margin-bottom: 15px; }
    .scorer-buttons button, .btn-edit-run { 
        height: 54px; width: 100%; border-radius: 8px; 
        font-weight: 800; font-size: 18px; font-family: var(--font-heading);
        background: rgba(22, 22, 40, 0.95); color: #fff; border: 1px solid rgba(223, 186, 115, 0.28); 
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        cursor: pointer;
        transition: all 0.15s ease;
    }
    .scorer-buttons button:hover, .btn-edit-run:hover { 
        transform: translateY(-2px); 
        border-color: var(--accent-gold); 
        background: rgba(223, 186, 115, 0.18);
        box-shadow: 0 6px 16px rgba(223, 186, 115, 0.3);
    }
    .scorer-buttons button:active, .btn-edit-run:active { transform: translateY(1px); }
    
    /* COLOR KEYS */
    .btn-4 { color: #34d399 !important; background: rgba(16, 185, 129, 0.18) !important; border-color: rgba(16, 185, 129, 0.5) !important; }
    .btn-6 { color: #e9d5ff !important; background: rgba(168, 85, 247, 0.22) !important; border-color: rgba(168, 85, 247, 0.6) !important; box-shadow: 0 0 15px rgba(168,85,247,0.3) !important; }
    .btn-w { color: #fca5a5 !important; background: rgba(244, 63, 94, 0.22) !important; border-color: rgba(244, 63, 94, 0.6) !important; }
    
    /* TABLES */
    .score-table th { background: rgba(223,186,115,0.08); color: var(--accent-gold-light); border-bottom: 1px solid rgba(223,186,115,0.3); }
    .score-table td { border-bottom: 1px solid rgba(255,255,255,0.06); padding: 10px 8px; font-size: 14px; }
    
    /* MISC */
    .result-banner { 
        background: rgba(16, 185, 129, 0.15); border: 1px solid #10b981; color: #34d399; 
        padding: 16px; border-radius: 10px; text-align: center; font-weight: 800; font-size: 16px;
        margin-bottom: 16px; box-shadow: 0 0 20px rgba(16, 185, 129, 0.25); 
    }
    .result-banner.tie { 
        background: rgba(245, 158, 11, 0.15); border-color: #f59e0b; color: #fbbf24; 
        box-shadow: 0 0 20px rgba(245, 158, 11, 0.25);
    }
    
    .chase-indicator { 
        background: rgba(6, 182, 212, 0.12); border: 1px solid rgba(6, 182, 212, 0.4); border-radius: 8px; 
        padding: 12px; margin-top: 12px; color: #67e8f9; font-size: 13.5px;
    }

    /* COMMENTARY STYLES */
    .comm-row {
        display: flex;
        align-items: flex-start;
        padding: 14px 16px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        gap: 14px;
        transition: background 0.15s;
    }
    .comm-row:hover {
        background: rgba(223, 186, 115, 0.04);
    }
    .comm-over {
        font-weight: 800;
        color: var(--accent-gold-light);
        font-size: 13px;
        min-width: 38px;
        padding-top: 6px;
    }
    .comm-ball {
        width: 38px;
        height: 38px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 900;
        font-size: 13.5px;
        flex-shrink: 0;
    }
    .comm-ball.normal { background: rgba(255,255,255,0.08); color: #fff; border: 1px solid rgba(255,255,255,0.2); }
    .comm-ball.four { background: rgba(16,185,129,0.25); color: #34d399; border: 1px solid #10b981; }
    .comm-ball.six { background: rgba(168,85,247,0.3); color: #e9d5ff; border: 1px solid #c084fc; box-shadow: 0 0 10px rgba(168,85,247,0.4); }
    .comm-ball.wicket { background: rgba(244,63,94,0.3); color: #fda4af; border: 1px solid #f43f5e; }
    .comm-ball.extra { background: rgba(245,158,11,0.25); color: #fde68a; border: 1px solid #f59e0b; font-size: 11px; }
    .comm-ball.nb6 { background: linear-gradient(135deg, rgba(168,85,247,0.5), rgba(245,158,11,0.5)); color: #fff; border: 1px solid #f5d77f; font-size: 11.5px; box-shadow: 0 0 12px rgba(223,186,115,0.4); }
    
    .comm-text { flex: 1; font-size: 14px; line-height: 1.5; color: #e2e8f0; }
    
    /* SUMMARY ROW */
    .comm-summary {
        background: rgba(22, 22, 40, 0.7);
        border-bottom: 1px solid rgba(223, 186, 115, 0.2);
        padding: 14px 16px;
        font-size: 13px;
        color: #cbd5e1;
        display: flex;
        flex-direction: column;
        gap: 8px;
    }
    .comm-summary-title { font-weight: 800; color: var(--accent-gold-light); font-size: 11px; text-transform: uppercase; letter-spacing: 1px; display:flex; justify-content:space-between; }
    .comm-summary-stats { display: flex; justify-content: space-between; align-items: center; }
    .comm-summary-score { font-weight: 900; font-size: 18px; color: #fff; font-family: var(--font-heading); }

    /* Modal */
    .modal-wrap { position:fixed; inset:0; background:rgba(5,5,12,0.85); backdrop-filter:blur(8px); z-index:2000; display:none; align-items:center; justify-content:center; }
    .modal-box { background:#141426; width:90%; max-width:420px; padding:24px; border-radius:var(--border-radius-lg); border:1px solid var(--accent-gold); box-shadow:0 16px 40px rgba(0,0,0,0.8), var(--gold-glow); text-align:center; }
    
    /* WICKET MODAL GRID */
    .wicket-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 15px; }
    .wicket-btn { padding: 14px; font-weight: 800; text-transform: uppercase; border: 1px solid rgba(223, 186, 115, 0.3); background: rgba(255,255,255,0.04); color: #fff; border-radius: 8px; cursor: pointer; transition:0.15s; }
    .wicket-btn:hover { background: var(--accent-gold); color: #090912; transform: translateY(-2px); box-shadow: var(--shadow-gold); }

    /* Player Select Grid with Swap Button */
    .player-select { 
        display: grid; 
        grid-template-columns: 1fr auto 1fr; 
        gap: 8px; 
        margin-bottom: 15px; 
        padding: 14px; 
        border: 1px dashed rgba(223, 186, 115, 0.3); 
        border-radius: 8px; 
        background: rgba(255, 255, 255, 0.02); 
        align-items: center;
    }
    .player-select label { font-size: 11px; font-weight:700; text-transform:uppercase; color: var(--accent-gold-light); }
    
    .btn-swap-batters {
        padding: 0; 
        width: 42px; 
        height: 42px; 
        border-radius: 50%; 
        display: flex; 
        align-items: center; 
        justify-content: center; 
        background: var(--gold-gradient); 
        color: #070710; 
        font-weight: 900; 
        font-size: 20px; 
        border: none; 
        cursor: pointer;
        box-shadow: 0 4px 12px rgba(223, 186, 115, 0.35);
        transition: transform 0.2s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    .btn-swap-batters:hover {
        transform: scale(1.1) rotate(180deg);
        box-shadow: var(--gold-glow);
    }
    .btn-swap-batters:active {
        transform: scale(0.95);
    }
  </style>
<link rel="manifest" href="../manifest.json">
<link rel="icon" type="image/png" href="../assets/logo.png">
<link rel="apple-touch-icon" href="../assets/icon-192.png">
<meta name="theme-color" content="#070710">
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('../sw.js');
  }
</script>
</head>
<body>

<div id="sticky-header" class="sticky-header">
    <div id="sticky-left" class="sticky-left"></div>
    <div id="sticky-right" class="sticky-right"></div>
</div>

<div id="modal-bowler" class="modal-wrap">
  <div class="modal-box">
    <h3>End of Over</h3>
    <p class="muted">Who is bowling next?</p>
    <select id="new-bowler-select" style="width:100%; padding:10px; border-radius:6px; background:#181830; color:#fff; border:1px solid rgba(223,186,115,0.4);"></select>
    <button onclick="confirmNewBowler()" class="btn" style="width:100%; margin-top:15px; background:var(--gold-gradient); color:#070710; font-weight:800;">Start Next Over</button>
  </div>
</div>

<div id="modal-batsman" class="modal-wrap">
  <div class="modal-box">
    <h3>Fall of Wicket</h3>
    <p class="muted" id="modal-batsman-desc">Who is the new batter coming in?</p>
    <select id="new-batsman-select" style="width:100%; padding:10px; border-radius:6px; background:#181830; color:#fff; border:1px solid rgba(223,186,115,0.4);"></select>
    
    <div style="margin-top:15px; text-align:left;">
        <label style="font-size:11px; font-weight:700; color:var(--accent-gold-light); text-transform:uppercase;">Position</label>
        <div style="display:flex; gap:10px; margin-top:5px;">
            <label style="display:flex; align-items:center; gap:5px; font-size:13px; cursor:pointer;"><input type="radio" name="batsman-target-pos" id="pos-striker" value="striker" checked> Striker End</label>
            <label style="display:flex; align-items:center; gap:5px; font-size:13px; cursor:pointer;"><input type="radio" name="batsman-target-pos" id="pos-nonstriker" value="nonstriker"> Non-Striker End</label>
        </div>
    </div>

    <button onclick="confirmNewBatsman()" class="btn" style="width:100%; margin-top:15px; background:var(--gold-gradient); color:#070710; font-weight:800;">Send In</button>
  </div>
</div>

<div id="modal-wicket" class="modal-wrap">
  <div class="modal-box">
    <h3 id="wicket-title">Wicket Type</h3>
    
    <div id="wicket-step-1" class="wicket-grid">
       <button class="wicket-btn" onclick="selWicket('bowled')">Bowled</button>
       <button class="wicket-btn" onclick="selWicket('caught')">Catch</button>
       <button class="wicket-btn" onclick="selWicket('stumped')">Stumped</button>
       <button class="wicket-btn" onclick="selWicket('lbw')">LBW</button>
       <button class="wicket-btn" onclick="selWicket('hit wicket')">Hit Wicket</button>
       <button class="wicket-btn" onclick="selWicket('run out')" style="background:rgba(244,63,94,0.15); border-color:#f43f5e; color:#fda4af;">Run Out</button>
    </div>

    <div id="wicket-step-2" style="display:none;">
       <p class="muted" style="margin-bottom:15px;">Who is out?</p>
       <div class="wicket-grid">
         <button id="btn-out-striker" class="wicket-btn" onclick="selWho('striker')">Striker</button>
         <button id="btn-out-nonstriker" class="wicket-btn" onclick="selWho('non_striker')">Non-Striker</button>
       </div>
    </div>

    <div id="wicket-step-3" style="display:none;">
       <p class="muted">Runs Completed by Batters</p>
       <input type="number" id="wicket-runs" value="0" style="font-size:32px; font-weight:bold; text-align:center; padding:10px; margin-bottom:20px; width:100px; border:2px solid var(--accent-gold); border-radius:8px; background:#181830; color:#fff;">
       
       <div style="display:flex; gap:15px; justify-content:center; margin-bottom:25px;">
          <label style="font-weight:bold; display:flex; align-items:center; gap:5px;"><input type="checkbox" id="wicket-wd" style="width:20px; height:20px;"> Wide</label>
          <label style="font-weight:bold; display:flex; align-items:center; gap:5px;"><input type="checkbox" id="wicket-nb" style="width:20px; height:20px;"> No Ball</label>
       </div>

       <button class="btn" style="width:100%; background:var(--pop-red); color:white; padding:15px; font-weight:800;" onclick="submitWicket()">CONFIRM OUT</button>
    </div>
    
    <button class="btn danger" style="margin-top:20px; width:100%; border:none; background:rgba(255,255,255,0.08); color:#cbd5e1;" onclick="closeWicketModal()">Cancel</button>
  </div>
</div>

<div id="modal-edit-ball" class="modal-wrap">
  <div class="modal-box">
    <h3>Edit Ball</h3>
    <input type="hidden" id="edit-ball-id">
    
    <div style="margin-bottom:15px; text-align:left;">
        <label>Runs (Bat)</label>
        <div class="scorer-grid" style="grid-template-columns:repeat(7, 1fr); gap:5px; margin-top:5px;">
            <button onclick="setEditRun(0)" class="btn-edit-run">0</button>
            <button onclick="setEditRun(1)" class="btn-edit-run">1</button>
            <button onclick="setEditRun(2)" class="btn-edit-run">2</button>
            <button onclick="setEditRun(3)" class="btn-edit-run">3</button>
            <button onclick="setEditRun(4)" class="btn-edit-run">4</button>
            <button onclick="setEditRun(6)" class="btn-edit-run">6</button>
        </div>
        <input type="number" id="edit-runs-input" style="width:60px; padding:6px; margin-top:5px; border-radius:4px; background:#181830; color:#fff; border:1px solid #444;">
    </div>

    <div style="margin-bottom:15px; text-align:left;">
        <label>Extras</label><br>
        <select id="edit-extras-type" style="padding:8px; border-radius:4px; background:#181830; color:#fff; border:1px solid #444;">
            <option value="">None</option>
            <option value="wd">Wide</option>
            <option value="nb">No Ball</option>
            <option value="lb">Leg Bye</option>
            <option value="b">Bye</option>
        </select>
        <input type="number" id="edit-extras-runs" placeholder="+Runs" value="0" style="width:60px; padding:8px; border-radius:4px; background:#181830; color:#fff; border:1px solid #444;">
    </div>

    <div style="margin-bottom:15px; text-align:left;">
        <label>Wicket?</label>
        <select id="edit-wicket-type" style="padding:8px; width:100%; border-radius:4px; background:#181830; color:#fff; border:1px solid #444;">
            <option value="">Not Out</option>
            <option value="bowled">Bowled</option>
            <option value="caught">Caught</option>
            <option value="lbw">LBW</option>
            <option value="run out">Run Out</option>
        </select>
    </div>

    <button onclick="submitEditBall()" class="btn" style="width:100%; background:var(--gold-gradient); color:#070710; font-weight:800;">Save Changes</button>
    <button onclick="document.getElementById('modal-edit-ball').style.display='none'" class="btn danger" style="width:100%; margin-top:10px; background:rgba(255,255,255,0.08); color:#cbd5e1;">Cancel</button>
  </div>
</div>

<div id="modal-innings-complete" class="modal-wrap">
  <div class="modal-box" style="text-align:center; max-width:420px; border:2px solid var(--accent-gold); box-shadow:0 0 25px rgba(223,186,115,0.35);">
    <div style="font-size:36px; margin-bottom:8px;">🏁</div>
    <h3 style="color:var(--accent-gold-light); margin:0 0 6px 0; font-size:20px; text-transform:uppercase; letter-spacing:1px;">1st Innings Complete</h3>
    <p class="muted" style="font-size:13px; margin-bottom:16px;"><span id="inn-complete-bat-team" style="color:#fff; font-weight:bold;">Team</span> innings has ended.</p>
    
    <div style="background:#131326; border:1px solid rgba(223,186,115,0.3); border-radius:12px; padding:16px; margin-bottom:18px;">
        <div style="font-size:11px; color:#94a3b8; text-transform:uppercase; font-weight:800; letter-spacing:1px;">Final Innings Score</div>
        <div id="inn-complete-score" style="font-size:28px; font-weight:900; color:#fff; margin:6px 0 10px 0;">0/0 (0.0 Ov)</div>
        <div id="inn-complete-target-text" style="font-size:16px; font-weight:bold; color:var(--accent-gold); padding:8px; background:rgba(223,186,115,0.1); border-radius:8px;">Target: 1 Run</div>
    </div>

    <button onclick="confirmStartInnings2()" class="btn" style="width:100%; padding:14px; background:var(--gold-gradient); color:#070710; font-weight:900; font-size:15px; border-radius:8px; box-shadow:0 4px 15px rgba(223,186,115,0.4); cursor:pointer;">
        🚀 START INNINGS 2 (CHASE)
    </button>
    <button onclick="document.getElementById('modal-innings-complete').style.display='none'" class="btn danger" style="width:100%; margin-top:10px; background:rgba(255,255,255,0.08); color:#cbd5e1; border:none; padding:10px; cursor:pointer;">
        Review Scorecard
    </button>
  </div>
</div>

<div id="modal-match-ended" class="modal-wrap">
  <div class="modal-box" style="text-align:center; max-width:420px; border:2px solid #34d399; box-shadow:0 0 25px rgba(52,211,153,0.3);">
    <div style="font-size:36px; margin-bottom:8px;">🏆</div>
    <h3 style="color:#34d399; margin:0 0 6px 0; font-size:20px; text-transform:uppercase; letter-spacing:1px;">Match Finished</h3>
    <div id="match-ended-summary" style="font-size:16px; font-weight:bold; color:#fff; margin:15px 0 20px 0; padding:12px; background:#131326; border-radius:10px; border:1px solid rgba(52,211,153,0.3);"></div>
    <button onclick="document.getElementById('modal-match-ended').style.display='none'; refresh();" class="btn" style="width:100%; padding:14px; background:var(--gold-gradient); color:#070710; font-weight:900; font-size:15px; border-radius:8px; cursor:pointer;">
        View Final Scorecard & Result
    </button>
  </div>
</div>

<div class="wrap">
  <div class="topbar">
    <div class="brand">
      <a href="../index.php" class="brand-link">
       <img src="../assets/logo.png" alt="Logo">
      </a>
    </div>
     <div class="top-actions">
        <?php if($canEdit): ?><a class="chip" href="#" onclick="return doLogout()">Logout</a><?php else: ?><a class="chip" href="login.php">Login</a><?php endif; ?>
     </div>
  </div>
  <div style="margin-bottom:15px;"><a href="javascript:history.back()" style="font-weight:700;">← Back</a></div>

  <div id="result-banner" class="result-banner" style="display:none;"></div>
  
  <div id="mom-container"></div>

  <div id="meta" class="card" style="text-align:center;">Loading...</div>

  <!-- TOSS / SETUP CARD (For Scheduled Matches / Fresh 2nd Matches) -->
  <div id="toss-area" style="display:none;"></div>

  <div id="scorer-area" style="display:none;">
     <div class="score-display">
         <div class="inn-switcher">
             <select id="active-inn-sel" onchange="manualSwitchInnings(this.value)" style="border:1px solid rgba(223,186,115,0.4);"></select>
         </div>
         <div id="view" style="display:none;"></div>
     </div>

     <?php if ($canEdit): ?>
     <div class="player-select">
        <div>
            <label>Striker</label>
            <select id="striker"></select>
        </div>
        
        <div style="padding-top: 18px;">
            <button onclick="swapBatters()" class="btn-swap-batters" title="Swap Striker and Non-Striker">⇄</button>
        </div>

        <div>
            <label>Non-Striker</label>
            <select id="nonstriker"></select>
        </div>
        
        <div style="grid-column: span 3;">
            <label>Current Bowler</label>
            <select id="bowler"></select>
        </div>
     </div>

     <div class="scorer-buttons">
        <div class="scorer-grid">
            <button onclick="addBall(0)">0</button>
            <button onclick="addBall(1)">1</button>
            <button onclick="addBall(2)">2</button>
            <button onclick="addBall(3)">3</button>
            <button onclick="addBall(4)" class="btn-4">4</button>
            <button onclick="addBall(6)" class="btn-6">6</button>
        </div>
        <div class="scorer-grid">
            <button onclick="addExtraPrompt('wd')" style="color:#ab47bc;">WD</button>
            <button onclick="addExtraPrompt('nb')" style="color:#ff5722;">NB</button>
            <button onclick="addExtraPrompt('b')" style="color:#00bcd4;">B</button>
            <button onclick="addExtraPrompt('lb')" style="color:#009688;">LB</button>
            <button onclick="openWicketModal()" class="btn-w" style="grid-column:span 2;">OUT</button>
        </div>
        <div class="scorer-actions" style="display:grid; grid-template-columns:1fr 1fr 1fr; gap:10px;">
          <button class="danger" onclick="undoBall()">Undo</button>
          <button onclick="refresh()">Refresh</button>
          <button style="border:2px dashed #dfba73;" onclick="endInnings()">End Inn</button>
        </div>
     </div>
     <?php endif; ?>
  </div>

  <div class="card">
     <div class="tabs">
        <div class="tab active" id="tb-scorecard" onclick="switchTab('scorecard')">Scorecard</div>
        <div class="tab" id="tb-summary" onclick="switchTab('summary')">Summary</div>
        <div class="tab" id="tb-graphs" onclick="switchTab('graphs')">Charts</div>
        <div class="tab" id="tb-comm" onclick="switchTab('comm')">Comm</div>
     </div>
     
     <div id="tab-scorecard" style="display:block;"></div>
     <div id="tab-summary" style="display:none;"></div>
     <div id="tab-graphs" style="display:none; padding:10px;"><canvas id="compChart"></canvas></div>
     <div id="tab-comm" style="display:none;"></div>
  </div>
</div>

<script>
const matchId = <?= $id ?>;
const CAN_EDIT = <?= $canEdit ? 'true' : 'false' ?>;
let matchData = null;
let currentInnings = null;
let manualInningsId = null;
let refreshInterval = null;
let chart = null;
let lastProcessedBallId = null; 
let targetBatsmanSlot = 'striker';

// WICKET MODAL STATE
let wType = '';
let wWho = '';

window.addEventListener('scroll', () => {
  const sc = document.querySelector('.score-display');
  const h = document.getElementById('sticky-header');
  if(sc && h) h.classList.toggle('visible', sc.getBoundingClientRect().bottom < 80);
});

async function refresh() {
    try {
        const r = await fetch(`../api/match_get.php?match_id=${matchId}&include_balls=1&t=${Date.now()}`);
        matchData = await r.json();
        
        if(matchData.error) {
            document.getElementById('meta').innerHTML = `<div style="color:red; text-align:center; padding:20px;">${matchData.error}</div>`;
            return;
        }

        render();
        if(CAN_EDIT) updateAutoDetect();
        
        if(!CAN_EDIT && (matchData.match.status === 'completed' || matchData.match.status === 'match_tied')) {
             if(refreshInterval) clearInterval(refreshInterval);
        }
    } catch(e) { console.error(e); }
}

function manualSwitchInnings(id) {
    manualInningsId = parseInt(id);
    lastProcessedBallId = null; // Reset to allow proper re-detection on innings switch
    render();
    if(CAN_EDIT) updateAutoDetect();
}

function render() {
    const m = matchData.match;
    let finalHtml = m.is_final == 1 ? '<div style="margin-bottom:10px;"><span style="background:#ffeb3b; color:#070710; padding:4px 10px; font-weight:bold; border-radius:4px;">🏆 GRAND FINAL</span></div>' : '';
    
    document.getElementById('meta').innerHTML = finalHtml + `
        <h2><span class="team-sticker" style="background:#fff; color:#000; border:1px solid #000;">${m.team_a}</span> <span style="font-size:16px; color:#888;">VS</span> <span class="team-sticker" style="background:#000; color:#fff;">${m.team_b}</span></h2>
        <div class="muted" style="margin-top:10px; font-weight:600;">${m.status.toUpperCase().replace('_',' ')} &nbsp;&bull;&nbsp; ${m.overs_limit} Overs</div>
    `;

    const banner = document.getElementById('result-banner');
    const scorer = document.getElementById('scorer-area');
    const tossArea = document.getElementById('toss-area');
    const momContainer = document.getElementById('mom-container');
    
    banner.style.display = 'none';
    momContainer.innerHTML = ''; 

    // Handle Scheduled Match / Toss Setup
    if ((!matchData.innings || matchData.innings.length === 0 || m.status === 'scheduled') && CAN_EDIT) {
        scorer.style.display = 'none';
        tossArea.style.display = 'block';
        tossArea.innerHTML = `
            <div class="card" style="text-align:center; max-width:480px; margin:20px auto; border:1px solid var(--accent-gold); box-shadow:var(--shadow-card);">
                <h3 style="color:var(--accent-gold-light); margin-bottom:8px;">🪙 Toss & Match Setup</h3>
                <p class="muted" style="margin-bottom:16px; font-size:13px;">Record the toss to begin scoring Match #${m.id}</p>
                <div style="text-align:left; margin-bottom:14px;">
                    <label style="font-size:11px; font-weight:800; color:var(--accent-gold-light); text-transform:uppercase;">Toss Winner</label>
                    <select id="toss-winner-select" style="width:100%; margin-top:5px; padding:10px; border-radius:6px; background:#181830; color:#fff; border:1px solid rgba(223,186,115,0.4);">
                        <option value="${m.team_a_id}">${m.team_a}</option>
                        <option value="${m.team_b_id}">${m.team_b}</option>
                    </select>
                </div>
                <div style="text-align:left; margin-bottom:20px;">
                    <label style="font-size:11px; font-weight:800; color:var(--accent-gold-light); text-transform:uppercase;">Decision</label>
                    <select id="toss-decision-select" style="width:100%; margin-top:5px; padding:10px; border-radius:6px; background:#181830; color:#fff; border:1px solid rgba(223,186,115,0.4);">
                        <option value="bat">Elected to BAT first</option>
                        <option value="bowl">Elected to BOWL first</option>
                    </select>
                </div>
                <button onclick="submitToss()" class="btn" style="width:100%; padding:14px; background:var(--gold-gradient); color:#070710; font-weight:900; border-radius:8px; font-size:15px;">⚡ START MATCH NOW</button>
            </div>
        `;
        return;
    } else {
        tossArea.style.display = 'none';
        scorer.style.display = 'block';
    }

    if (m.status === 'completed' || m.status === 'match_tied' || m.status === 'awaiting_super_over') {
        banner.style.display = 'block';
        if (m.status === 'match_tied' || m.status === 'awaiting_super_over' || m.result_type === 'tie') { 
            banner.className='result-banner tie'; 
            if (m.status === 'awaiting_super_over') {
                let btns = '';
                if(CAN_EDIT) {
                    btns = `<div style="margin-top:15px; display:flex; gap:10px; justify-content:center;">
                        <button class="btn" style="background:var(--pop-cyan); color:white;" onclick="startSuperOver()">Start Super Over</button>
                        <button class="btn" style="background:#fff; color:#000; border:2px solid #ccc;" onclick="endAsTie()">Keep as Tie</button>
                    </div>`;
                }
                banner.innerHTML = `<div>MATCH TIED (Super Over?)</div>${btns}`;
            } else banner.textContent = "MATCH TIED"; 
        }
        else if (m.result_type === 'nr') { banner.textContent="NO RESULT"; }
        else if (m.result_text) { banner.textContent = m.result_text; } 
        else { banner.textContent = "MATCH COMPLETED"; }
        
        // MAN OF THE MATCH LOGIC
        if (m.status === 'completed') {
            if (m.mom_name) {
                momContainer.innerHTML = `
                    <div class="card" style="text-align:center; border:2px solid #00bcd4; background:rgba(6,182,212,0.1); position:relative; margin-bottom:16px;">
                        <span style="font-size:11px; font-weight:900; color:#00bcd4; text-transform:uppercase;">🌟 Man of the Match</span>
                        <div style="font-size:20px; font-weight:bold; color:#fff; margin:5px 0;">${m.mom_name}</div>
                        ${CAN_EDIT ? `<button class="chip" onclick="showMomEditor()" style="border:none; cursor:pointer; background:rgba(255,255,255,0.1);">Change</button>` : ''}
                    </div>`;
            } else if (CAN_EDIT) {
                momContainer.innerHTML = `
                    <div class="card" style="text-align:center; border:2px dashed rgba(223,186,115,0.4); margin-bottom:16px;">
                        <h4 style="margin-bottom:10px;">Select Man of the Match</h4>
                        <select id="mom-select" style="padding:8px; margin-bottom:10px; width:220px; border-radius:6px; background:#181830; color:#fff; border:1px solid rgba(223,186,115,0.4);">
                            <option value="">-- Select Player --</option>
                            ${matchData.players.map(p => `<option value="${p.id}">${p.name}</option>`).join('')}
                        </select><br>
                        <button class="btn" onclick="saveMOM()" style="padding:8px 18px; background:var(--gold-gradient); color:#070710; font-weight:800; border-radius:6px;">Save Selection</button>
                    </div>`;
            }
        }
    }

    currentInnings = null; 
    if (manualInningsId) currentInnings = matchData.innings.find(i => i.id === manualInningsId);
    if (!currentInnings && matchData.innings) currentInnings = matchData.innings.find(i => !i.completed) || matchData.innings[matchData.innings.length-1];

    const sel = document.getElementById('active-inn-sel');
    if(sel && matchData.innings) {
        sel.innerHTML = matchData.innings.map(i => `<option value="${i.id}" ${currentInnings && currentInnings.id === i.id ? 'selected' : ''}>Innings ${i.innings_no}: ${i.batting_team}</option>`).join('');
    }
    
    if(currentInnings) {
        const s = currentInnings.summary;
        let chaseHtml = '';
        let stickyChase = `<span>CRR ${s.rr}</span>`;

        if (matchData.chase && matchData.chase.innings_no === currentInnings.innings_no) {
             const c = matchData.chase;
             chaseHtml = `<div class="chase-indicator">🎯 Target ${c.target} &bull; Need <b>${c.required_runs}</b> off <b>${c.remaining_balls}</b> <small>(RR ${c.required_rr})</small></div>`;
             stickyChase = `<span class="sticky-req">Need ${c.required_runs} off ${c.remaining_balls}</span>`;
        }

        let partHtml = '';
        if(!currentInnings.completed && currentInnings.current_partnership) {
            const p = currentInnings.current_partnership;
            partHtml = `<div style="margin-top:10px; font-size:13px; color:#cbd5e1; border-top:1px dashed rgba(223,186,115,0.3); padding-top:5px;">Partnership: <b>${p.runs}</b> (${p.balls})</div>`;
        }

        const tName = currentInnings.batting_team_id == m.team_a_id ? (m.team_a_short||m.team_a) : (m.team_b_short||m.team_b);
        document.getElementById('sticky-left').innerHTML = `<div class="sticky-team">${tName}</div><div class="sticky-score">${s.runs}/${s.wkts} <span class="sticky-overs">${s.overs_text} Ov</span></div>`;
        document.getElementById('sticky-right').innerHTML = stickyChase;

        document.getElementById('view').style.display = 'block';
        document.getElementById('view').innerHTML = `
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <div class="team-sticker">${currentInnings.batting_team}</div>
                <div style="text-align:right;">
                   <div class="score-big">${s.runs}/${s.wkts}</div>
                   <div class="muted" style="font-size:14px; font-weight:bold;">${s.overs_text} Ov &bull; CRR ${s.rr}</div>
                </div>
            </div>
            ${partHtml} ${chaseHtml}
            ${CAN_EDIT ? `<div style="margin-top:12px; display:flex; gap:4px; flex-wrap:wrap;">${s.recent_balls.map(formatPill).join('')}</div>` : ''}
        `;
    }
    renderTabs();
    renderCompChart();
}

async function submitToss() {
    const winner = document.getElementById('toss-winner-select').value;
    const dec = document.getElementById('toss-decision-select').value;
    const fd = new FormData();
    fd.append('match_id', matchId);
    fd.append('toss_winner_team_id', winner);
    fd.append('toss_decision', dec);
    try {
        const r = await fetch('../api/match_start.php', { method: 'POST', body: fd });
        const j = await r.json();
        if (j.ok) {
            refresh();
        } else {
            alert(j.error || 'Failed to start match');
        }
    } catch(e) {
        alert('Error starting match: ' + e.message);
    }
}

function showMomEditor() {
    matchData.match.mom_name = null; 
    render();
}

async function saveMOM() {
    const pid = document.getElementById('mom-select').value;
    if(!pid) return alert("Please select a player");
    
    const fd = new FormData();
    fd.append('match_id', matchId);
    fd.append('player_id', pid);

    try {
        const response = await fetch('../api/match_set_mom.php', {
            method: 'POST',
            body: fd
        });
        const res = await response.json();
        if(res.ok) {
            refresh();
        } else {
            alert("Error: " + res.error);
        }
    } catch(e) {
        console.error("MOM Save Failed:", e);
    }
}

function renderTabs() {
    if (!matchData.innings) return;
    let scHtml = '', sumHtml = '';
    matchData.innings.forEach(inn => {
        const ex = inn.scorecard.extras || {};
        const extrasStr = `Extras: <b>${ex.total||0}</b> (WD ${ex.wides||0}, NB ${ex.no_balls||0}, B ${ex.byes||0}, LB ${ex.leg_byes||0})`;

        scHtml += `<div style="border:1px solid rgba(223,186,115,0.25); border-radius:8px; padding:15px; margin-bottom:20px; background:#141426; box-shadow:var(--shadow-card);">
            <h3 style="margin:0 0 10px 0; border-bottom:1px solid rgba(223,186,115,0.2); padding-bottom:8px;">
                <span class="team-sticker" style="font-size:14px;">${inn.batting_team}</span> 
                <span style="float:right; font-size:18px; font-weight:900; color:var(--accent-gold-light);">${inn.summary.runs}/${inn.summary.wkts}</span>
            </h3>
            <div class="table-responsive"><table class="score-table"><thead><tr><th>Batter</th><th>R</th><th>B</th><th>4s</th><th>6s</th><th>SR</th></tr></thead><tbody>
            ${inn.scorecard.batsmen.map(b => {
                const sr = b.balls > 0 ? ((b.runs/b.balls)*100).toFixed(1) : '0.0';
                const outText = b.dismissal ? `<span style="display:block; font-size:10px; color:#f43f5e; font-weight:bold;">${b.dismissal}</span>` : `<span style="display:block; font-size:10px; color:#34d399;">not out</span>`;
                return `<tr><td><a href="player.php?id=${b.id}" style="color:#fff; text-decoration:none; font-weight:700;">${b.name}</a>${b.is_captain==1?' (c)':''} ${outText}</td><td><b>${b.runs}</b></td><td>${b.balls}</td><td>${b.fours}</td><td>${b.sixes}</td><td>${sr}</td></tr>`;
            }).join('')}
            </tbody></table></div>
            <div style="padding:10px; background:rgba(255,255,255,0.02); border-bottom:1px solid rgba(255,255,255,0.05); font-size:13px; color:#cbd5e1;">${extrasStr}</div>
            <div style="height:15px;"></div>
            <div class="table-responsive"><table class="score-table"><thead><tr><th>Bowler</th><th>O</th><th>R</th><th>W</th><th style="font-size:10px; color:#cbd5e1;">WD</th><th style="font-size:10px; color:#cbd5e1;">NB</th><th>Econ</th></tr></thead><tbody>
            ${inn.scorecard.bowlers.map(b => {
                 const overs = Math.floor(b.legal_balls/6) + '.' + (b.legal_balls%6);
                 const econ = b.legal_balls > 0 ? ((b.runs_conceded / b.legal_balls)*6).toFixed(1) : '-';
                 return `<tr><td><a href="player.php?id=${b.id}" style="color:#fff; text-decoration:none; font-weight:700;">${b.name}</a></td><td>${overs}</td><td>${b.runs_conceded}</td><td><b>${b.wickets}</b></td><td style="color:#94a3b8; font-size:12px;">${b.wides}</td><td style="color:#94a3b8; font-size:12px;">${b.no_balls}</td><td>${econ}</td></tr>`;
            }).join('')}
            </tbody></table></div>
            ${inn.fow.length > 0 ? `<div style="margin-top:15px; font-weight:bold; font-size:12px; color:var(--accent-gold-light);">Fall of Wickets:</div><div style="font-size:12px; line-height:1.6; color:#cbd5e1;">${inn.fow.map(f => `${f.score}-${f.wicket} (${f.player}, ${f.over} ov)`).join(', ')}</div>` : ''}
        </div>`;

        sumHtml += `<h4 style="margin:20px 0 10px 0; display:inline-block;"><span class="team-sticker">${inn.batting_team}</span></h4>`;
        if(!inn.overs_history?.length) sumHtml += '<div class="muted">No balls yet.</div>';
        else {
            sumHtml += inn.overs_history.map(o => `
                <div style="border-bottom:1px solid rgba(255,255,255,0.08); padding:8px 0; display:flex; justify-content:space-between; align-items:center;">
                   <div style="font-weight:bold; font-size:13px;">Over ${o.over} <span class="muted" style="font-weight:400;">(${o.bowler})</span></div>
                   <div style="display:flex; gap:3px; flex-wrap:wrap;">
                     ${o.balls.map(x => `<span onclick="openEditBall(${x.id}, ${x.runs_bat}, '${x.extras_type||''}', ${x.extras_runs||0}, '${x.wicket_type||''}')" style="cursor:pointer">${formatPill(x.label)}</span>`).join('')}
                   </div>
                </div>`).join('');
        }
    });
    
    document.getElementById('tab-scorecard').innerHTML = scHtml;
    document.getElementById('tab-summary').innerHTML = sumHtml;
    if(currentInnings) {
        document.getElementById('tab-comm').innerHTML = currentInnings.commentary.map(c => {
            if (c.type === 'over_end') {
                return `<div class="comm-summary">
                    <div class="comm-summary-title"><span>${c.over}</span> <span style="font-weight:900; color:var(--accent-gold-light);">Runs this over: ${c.this_over_runs}</span></div>
                    <div class="comm-summary-stats">
                        <div class="comm-summary-score">${c.score}</div>
                        <div>${c.batsmen}</div>
                    </div>
                    <div style="text-align:right; font-size:11px; color:#94a3b8;">${c.partnership}</div>
                </div>`;
            }
            
            let ballHtml = '';
            if (c.is_wicket) ballHtml = '<div class="comm-ball wicket">W</div>';
            else if (c.extras_type === 'nb' && c.runs_bat == 6) ballHtml = '<div class="comm-ball nb6">NB6</div>';
            else if (c.runs_bat == 6) ballHtml = '<div class="comm-ball six">6</div>';
            else if (c.runs_bat == 4) ballHtml = '<div class="comm-ball four">4</div>';
            else if (c.extras_type) ballHtml = `<div class="comm-ball extra">${c.extras_type.toUpperCase()}${c.runs_bat > 0 ? c.runs_bat : ''}</div>`;
            else ballHtml = `<div class="comm-ball normal">${c.runs}</div>`;

            return `<div class="comm-row">
                <div class="comm-over">${c.over}</div>
                <div class="comm-score">${ballHtml}</div>
                <div class="comm-text">${c.text}</div>
            </div>`;
        }).join('');
    }
}

function renderCompChart() {
    const chartEl = document.getElementById('compChart');
    if (!chartEl || !matchData.innings) return;
    const ctx = chartEl.getContext('2d');
    const datasets = [];
    matchData.innings.forEach((inn, idx) => {
        const color = idx===0 ? '#dfba73' : '#38bdf8';
        const borderColor = idx===0 ? '#f5d77f' : '#0ea5e9';
        datasets.push({ 
            type: 'line', 
            label: inn.batting_team, 
            data: inn.graph_data, 
            borderColor: borderColor, 
            backgroundColor: color, 
            borderWidth: 2, 
            tension: 0.1, 
            pointRadius: 0, 
            fill: false 
        });
        if (inn.wickets_data?.length > 0) datasets.push({ 
            type: 'scatter', 
            label: 'W', 
            data: inn.wickets_data, 
            backgroundColor: '#ff5252', 
            borderColor: '#b71c1c', 
            borderWidth: 1, 
            pointRadius: 6 
        });
    });
    if(chart) chart.destroy();
    chart = new Chart(ctx, { 
        data: { datasets: datasets }, 
        options: { 
            responsive: true, 
            scales: { 
                x: { 
                    type: 'linear', 
                    title: {display:true, text:'Overs', color:'#cbd5e1'}, 
                    grid: {color:'rgba(255,255,255,0.06)'},
                    ticks: { stepSize: 1, color:'#cbd5e1' }
                }, 
                y: { 
                    beginAtZero: true, 
                    title: {display:true, text:'Runs', color:'#cbd5e1'}, 
                    grid: {color:'rgba(255,255,255,0.06)'},
                    ticks: { color:'#cbd5e1' }
                } 
            } 
        } 
    });
}

function updateAutoDetect() {
    if(!currentInnings || currentInnings.completed == 1 || matchData.match.status === 'completed') return;

    const last = currentInnings.last_ball;
    const thisBallId = last ? last.id : 0;
    
    const batPlayers = matchData.players.filter(p => p.team_id == currentInnings.batting_team_id);
    const bowlPlayers = matchData.players.filter(p => p.team_id != currentInnings.batting_team_id);

    // Get dismissed players in this innings to mark them
    const dismissedIds = [];
    if (currentInnings && currentInnings.scorecard && currentInnings.scorecard.batsmen) {
        currentInnings.scorecard.batsmen.forEach(b => {
            if (b.dismissal) dismissedIds.push(parseInt(b.id));
        });
    }

    const populate = (id, list, selected) => { 
        const el = document.getElementById(id);
        if (!el) return;
        const currentVal = el.value;
        const targetVal = selected !== undefined && selected !== null ? selected : currentVal;
        
        el.innerHTML = '<option value="">Select...</option>'; 
        list.forEach(p => {
            const isOut = (id === 'striker' || id === 'nonstriker') && dismissedIds.includes(parseInt(p.id));
            const isSelected = p.id == targetVal;
            el.innerHTML += `<option value="${p.id}" ${isSelected ? 'selected' : ''} ${isOut ? 'style="color:#94a3b8;"' : ''}>${p.name}${isOut ? ' (Out)' : ''}</option>`;
        });
    };
    
    // If no ball bowled yet in this innings
    if(!last) { 
        populate('striker', batPlayers, document.getElementById('striker').value || ''); 
        populate('nonstriker', batPlayers, document.getElementById('nonstriker').value || ''); 
        populate('bowler', bowlPlayers, document.getElementById('bowler').value || ''); 
        lastProcessedBallId = thisBallId; 
        return; 
    }
    
    if (thisBallId === lastProcessedBallId && manualInningsId === null) return; 
    
    let s = last.striker_id, ns = last.non_striker_id, b = last.bowler_id;
    let runsRan = parseInt(last.runs_bat);
    if (runsRan % 2 !== 0 && runsRan !== 4 && runsRan !== 6) { let temp = s; s = ns; ns = temp; }
    if ((last.extras_type === 'b' || last.extras_type === 'lb') && parseInt(last.extras_runs) % 2 !== 0) { let temp = s; s = ns; ns = temp; }
    
    if (last.is_wicket == 1) { 
        const outId = parseInt(last.wicket_player_out_id);
        if(outId == s) { 
            s = ''; 
            showBatsmanModal(batPlayers, ns, 'striker'); 
        } else if(outId == ns) { 
            ns = ''; 
            showBatsmanModal(batPlayers, s, 'nonstriker'); 
        } else { 
            s = ''; 
            showBatsmanModal(batPlayers, ns, 'striker'); 
        } 
    }
    
    const oversLimit = parseInt(currentInnings.overs_limit_override || matchData.match.overs_limit || 20);
    const maxBalls = (oversLimit > 0 ? oversLimit : 20) * 6;
    const wicketsLimit = parseInt(matchData.match.wickets_limit || 10);
    const legal = parseInt(currentInnings.summary.legal_balls || 0);
    const totalWkts = parseInt(currentInnings.summary.wkts || currentInnings.summary.wickets || 0);
    const totalRuns = parseInt(currentInnings.summary.runs || 0);
    const target = parseInt(currentInnings.target || 0);

    const isInnComplete = (maxBalls > 0 && legal >= maxBalls) || (wicketsLimit > 0 && totalWkts >= wicketsLimit);
    const isMatchEnded = (currentInnings.innings_no == 2) && ((target > 0 && totalRuns >= target) || isInnComplete);

    if (currentInnings.innings_no == 1 && isInnComplete && !currentInnings.completed) {
        showInningsCompleteModal();
        return;
    }

    if (currentInnings.innings_no == 2 && isMatchEnded && matchData.match.status !== 'completed' && matchData.match.status !== 'awaiting_super_over') {
        showMatchEndedModal();
        return;
    }

    if(!isInnComplete && legal > 0 && legal % 6 === 0 && last.is_legal == 1) { 
        let temp = s; s = ns; ns = temp; b = ''; 
        if(!currentInnings.completed) showBowlerModal(bowlPlayers, last.bowler_id); 
    }
    
    populate('striker', batPlayers, s); 
    populate('nonstriker', batPlayers, ns); 
    populate('bowler', bowlPlayers, b);
    lastProcessedBallId = thisBallId;
}

function swapBatters() {
    const s = document.getElementById('striker');
    const ns = document.getElementById('nonstriker');
    if (!s || !ns) return;
    const tmp = s.value;
    s.value = ns.value;
    ns.value = tmp;
    
    s.style.boxShadow = '0 0 12px var(--accent-gold)';
    ns.style.boxShadow = '0 0 12px var(--accent-gold)';
    setTimeout(() => {
        s.style.boxShadow = '';
        ns.style.boxShadow = '';
    }, 400);
}

function openWicketModal() {
  if(!validateSel()) return;
  wType=''; wWho='';
  document.getElementById('wicket-runs').value = 0;
  document.getElementById('wicket-wd').checked = false;
  document.getElementById('wicket-nb').checked = false;
  
  document.getElementById('wicket-title').innerText = "Wicket Type";
  document.getElementById('wicket-step-1').style.display = 'grid';
  document.getElementById('wicket-step-2').style.display = 'none';
  document.getElementById('wicket-step-3').style.display = 'none';
  
  document.getElementById('modal-wicket').style.display = 'flex';
}

function selWicket(type) {
  wType = type;
  if(type === 'run out') {
     document.getElementById('wicket-title').innerText = "Run Out: Who?";
     document.getElementById('wicket-step-1').style.display = 'none';
     const sName = document.querySelector('#striker option:checked')?.text || 'Striker';
     const nsName = document.querySelector('#nonstriker option:checked')?.text || 'Non-Striker';
     document.getElementById('btn-out-striker').innerHTML = `STRIKER<span style="display:block; font-size:11px; font-weight:bold; text-transform:none; margin-top:5px; color:#f43f5e;">${sName}</span>`;
     document.getElementById('btn-out-nonstriker').innerHTML = `NON-STRIKER<span style="display:block; font-size:11px; font-weight:bold; text-transform:none; margin-top:5px; color:#f43f5e;">${nsName}</span>`;
     document.getElementById('wicket-step-2').style.display = 'grid';
  } else {
     wWho = 'striker'; 
     showRunsStep();
  }
}

function selWho(who) {
  wWho = who;
  showRunsStep();
}

function showRunsStep() {
  document.getElementById('wicket-title').innerText = "Wicket Details";
  document.getElementById('wicket-step-1').style.display = 'none';
  document.getElementById('wicket-step-2').style.display = 'none';
  document.getElementById('wicket-step-3').style.display = 'block';
  document.getElementById('wicket-runs').focus();
}

function closeWicketModal() {
  document.getElementById('modal-wicket').style.display = 'none';
}

async function submitWicket() {
  const runs = parseInt(document.getElementById('wicket-runs').value || 0);
  const isWd = document.getElementById('wicket-wd').checked;
  const isNb = document.getElementById('wicket-nb').checked;
  let exType = ''; let exRuns = 0;
  if(isWd) { exType='wd'; exRuns=1; }
  else if(isNb) { exType='nb'; exRuns=1; }
  const fd = new FormData();
  fd.append('innings_id', currentInnings.id);
  fd.append('runs_bat', runs);
  fd.append('extras_runs', exRuns);
  if(exType) fd.append('extras_type', exType);
  fd.append('is_wicket', 1);
  fd.append('wicket_type', wType);
  const sId = document.getElementById('striker').value;
  const nsId = document.getElementById('nonstriker').value;
  fd.append('striker_id', sId);
  fd.append('non_striker_id', nsId);
  fd.append('bowler_id', document.getElementById('bowler').value);
  let outId = sId;
  if(wWho === 'non_striker') outId = nsId;
  fd.append('wicket_player_out_id', outId);
  await postBall(fd);
  closeWicketModal();
}

async function startSuperOver() { if(confirm("Start Super Over?")) { await fetch('../api/super_over_start.php', {method:'POST', body:new URLSearchParams({match_id:matchId})}); location.reload(); } }
async function endAsTie() {
    if(!confirm("End Match as Tie?")) return;
    const fd = new FormData(); fd.append('match_id', matchId); fd.append('result', 'tie');
    await fetch('../api/match_result.php', {method:'POST', body:fd});
    location.reload();
}

function formatPill(label) { 
    let cls = 'pill'; 
    let bg = '#ffffff'; 
    let color = '#070710'; 
    let border = '#2c3e50'; 
    let glow = '';

    if (label.includes('W')) {
        cls = 'pill pill-w';
        bg = '#f43f5e';
        color = '#ffffff';
        border = '#e11d48';
    } else if (label === '6' || label === 'NB6') {
        cls = 'pill pill-6';
        bg = 'linear-gradient(135deg, #a855f7 0%, #7c3aed 100%)';
        color = '#ffffff';
        border = '#c084fc';
        glow = 'box-shadow: 0 0 10px rgba(168,85,247,0.5);';
    } else if (label === '4' || label === 'NB4') {
        cls = 'pill pill-4';
        bg = 'rgba(16, 185, 129, 0.9)';
        color = '#ffffff';
        border = '#10b981';
    } else if (label.startsWith('NB')) {
        bg = 'rgba(249, 115, 22, 0.9)';
        color = '#ffffff';
        border = '#ea580c';
    } else if (label.startsWith('WD')) {
        bg = 'rgba(168, 85, 247, 0.85)';
        color = '#ffffff';
        border = '#9333ea';
    } else if (label.includes('B') || label.includes('LB')) {
        bg = 'rgba(6, 182, 212, 0.85)';
        color = '#ffffff';
        border = '#0891b2';
    } else if (label === '0') {
        bg = 'rgba(255, 255, 255, 0.08)';
        color = '#94a3b8';
        border = 'rgba(255,255,255,0.2)';
    }

    return `<span class="${cls}" style="margin-right:3px; font-weight:900; font-family:var(--font-heading, sans-serif); padding:3px 7px; border:1px solid ${border}; border-radius:6px; background:${bg}; color:${color}; font-size:12px; display:inline-flex; align-items:center; justify-content:center; ${glow}">${label}</span>`; 
}

function switchTab(t){ ['summary','scorecard','graphs','comm'].forEach(x=>document.getElementById('tab-'+x).style.display='none'); ['tb-summary','tb-scorecard','tb-graphs','tb-comm'].forEach(x=>document.getElementById(x).classList.remove('active')); document.getElementById('tab-'+t).style.display='block'; document.getElementById('tb-'+t).classList.add('active'); }

function showBowlerModal(players, lastBowlerId) { 
    const el = document.getElementById('modal-bowler'); 
    const sel = document.getElementById('new-bowler-select'); 
    sel.innerHTML = '<option value="">Select Next Bowler...</option>'; 
    players.forEach(p => { 
        if(p.id != lastBowlerId) sel.innerHTML += `<option value="${p.id}">${p.name}</option>`; 
    }); 
    el.style.display = 'flex'; 
}

function confirmNewBowler() { 
    const val = document.getElementById('new-bowler-select').value; 
    if(val) { 
        document.getElementById('bowler').value = val; 
        document.getElementById('modal-bowler').style.display = 'none'; 
    } 
}

function showBatsmanModal(players, currentOtherId, targetSlot = 'striker') { 
    targetBatsmanSlot = targetSlot;
    const el = document.getElementById('modal-batsman'); 
    const sel = document.getElementById('new-batsman-select'); 
    
    // Exclude batsmen already dismissed in this innings
    const dismissedIds = [];
    if (currentInnings && currentInnings.scorecard && currentInnings.scorecard.batsmen) {
        currentInnings.scorecard.batsmen.forEach(b => {
            if (b.dismissal) dismissedIds.push(parseInt(b.id));
        });
    }

    sel.innerHTML = '<option value="">Select New Batsman...</option>'; 
    players.forEach(p => { 
        const pid = parseInt(p.id);
        if(pid != currentOtherId && !dismissedIds.includes(pid)) {
            sel.innerHTML += `<option value="${p.id}">${p.name}</option>`; 
        }
    }); 
    
    // Position radio default
    if (targetSlot === 'nonstriker') {
        document.getElementById('pos-nonstriker').checked = true;
    } else {
        document.getElementById('pos-striker').checked = true;
    }

    el.style.display = 'flex'; 
}

function confirmNewBatsman() { 
    const val = document.getElementById('new-batsman-select').value; 
    if(!val) return alert("Please choose a batsman");
    
    const chosenPos = document.querySelector('input[name="batsman-target-pos"]:checked')?.value || targetBatsmanSlot || 'striker';
    const targetEl = document.getElementById(chosenPos === 'nonstriker' ? 'nonstriker' : 'striker');
    if (targetEl) targetEl.value = val; 
    document.getElementById('modal-batsman').style.display = 'none'; 
}

async function addBall(runs) { if(validateSel()) await postBall(makeFD(runs, 0, '', '')); }

async function addExtraPrompt(type) { 
    if(!validateSel()) return; 
    let r = 0;
    if (type === 'nb') {
        const ans = prompt("Runs scored by batter off this No Ball?\n(0 for No Ball only, 4 for Four, 6 for Six, 1, 2, 3 runs)", "0");
        if (ans === null) return;
        r = parseInt(ans) || 0;
        await postBall(makeFD(r, 1, 'nb', ''));
    } else if (type === 'wd') {
        const ans = prompt("Additional overthrows / runs on Wide?\n(0 for regular 1 Wide, 1, 2, 3, 4 for extra runs)", "0");
        if (ans === null) return;
        r = parseInt(ans) || 0;
        await postBall(makeFD(0, 1 + r, 'wd', ''));
    } else if (type === 'b' || type === 'lb') {
        const ans = prompt(`${type.toUpperCase()} runs?\n(Enter 1, 2, 3, 4, etc.)`, "1");
        if (ans === null) return;
        r = parseInt(ans) || 1;
        await postBall(makeFD(0, r, type, ''));
    }
}

function validateSel() { 
    const s = document.getElementById('striker').value;
    const ns = document.getElementById('nonstriker').value;
    const b = document.getElementById('bowler').value;
    if(!s || !ns || !b) { 
        alert("Please select Striker, Non-Striker, and Bowler first."); 
        return false; 
    } 
    if (s === ns) {
        alert("Striker and Non-Striker cannot be the same player!");
        return false;
    }
    return true; 
}

function makeFD(runs, exRuns, exType, wType) { 
    const fd = new FormData(); 
    fd.append('innings_id', currentInnings.id); 
    fd.append('runs_bat', runs); 
    fd.append('extras_runs', exRuns); 
    if(exType) fd.append('extras_type', exType); 
    if(wType) fd.append('wicket_type', wType); 
    fd.append('striker_id', document.getElementById('striker').value); 
    fd.append('non_striker_id', document.getElementById('nonstriker').value); 
    fd.append('bowler_id', document.getElementById('bowler').value); 
    return fd; 
}

async function postBall(fd) { 
    try {
        const response = await fetch('../api/ball_add.php', {method:'POST', body:fd}); 
        const res = await response.json();
        if (res && (res.success || res.ok)) {
            if (res.is_innings_complete && currentInnings && currentInnings.innings_no === 1 && !currentInnings.completed) {
                await refresh();
                showInningsCompleteModal(res);
                return;
            } else if (res.is_match_ended && currentInnings && currentInnings.innings_no === 2) {
                await showMatchEndedModal();
                return;
            }
        }
        await refresh();
    } catch(e) {
        console.error("Ball post failed:", e);
        await refresh();
    }
}

function showInningsCompleteModal(ballRes) {
    if (!currentInnings) return;
    const runs = currentInnings.summary.runs;
    const wkts = currentInnings.summary.wkts;
    const oversText = currentInnings.summary.overs_text;
    const target = runs + 1;
    const battingTeam = currentInnings.batting_team;
    const bowlingTeam = (currentInnings.batting_team_id == matchData.match.team_a_id) ? matchData.match.team_b : matchData.match.team_a;

    const modal = document.getElementById('modal-innings-complete');
    if (modal) {
        const batEl = document.getElementById('inn-complete-bat-team');
        const scoreEl = document.getElementById('inn-complete-score');
        const targetEl = document.getElementById('inn-complete-target-text');
        if (batEl) batEl.innerText = battingTeam;
        if (scoreEl) scoreEl.innerText = `${runs}/${wkts} (${oversText} Ov)`;
        if (targetEl) targetEl.innerText = `Target for ${bowlingTeam}: ${target} Runs`;
        modal.style.display = 'flex';
    }
}

async function confirmStartInnings2() {
    if (!currentInnings) return;
    const modal = document.getElementById('modal-innings-complete');
    if (modal) modal.style.display = 'none';
    try {
        const res = await fetch('../api/innings_complete.php', {
            method: 'POST',
            body: new URLSearchParams({ innings_id: currentInnings.id })
        });
        const data = await res.json();
        manualInningsId = null;
        lastProcessedBallId = null;
        await refresh();
    } catch(e) {
        console.error('Error completing innings:', e);
        await refresh();
    }
}

async function showMatchEndedModal() {
    if (!currentInnings) return;
    try {
        const res = await fetch('../api/innings_complete.php', {
            method: 'POST',
            body: new URLSearchParams({ innings_id: currentInnings.id })
        });
        const data = await res.json();
        const modal = document.getElementById('modal-match-ended');
        if (modal) {
            let winText = "Match Completed!";
            if (data.next === 'tie') winText = "Match Tied! Super Over available.";
            else if (data.winner_team_id) {
                const wTeam = (data.winner_team_id == matchData.match.team_a_id) ? matchData.match.team_a : matchData.match.team_b;
                winText = `🎉 ${wTeam} Won the Match!`;
            }
            const sumEl = document.getElementById('match-ended-summary');
            if (sumEl) sumEl.innerText = winText;
            modal.style.display = 'flex';
        }
        manualInningsId = null;
        lastProcessedBallId = null;
        await refresh();
    } catch(e) {
        console.error('Error finalizing match:', e);
        await refresh();
    }
}

async function undoBall() { await fetch('../api/ball_undo.php', {method:'POST', body:new URLSearchParams({innings_id:currentInnings.id})}); refresh(); }
async function endInnings() { 
    if(confirm('End this Innings?')) { 
        await fetch('../api/innings_complete.php', {method:'POST', body:new URLSearchParams({innings_id:currentInnings.id})}); 
        manualInningsId = null;
        lastProcessedBallId = null;
        refresh(); 
    } 
}
async function doLogout(){ await fetch('../api/logout.php',{method:'POST'}); location.href='../index.php'; }

function openEditBall(id, runs, exType, exRuns, wType) {
    if(!CAN_EDIT) return;
    document.getElementById('edit-ball-id').value = id;
    document.getElementById('edit-runs-input').value = runs;
    document.getElementById('edit-extras-type').value = exType;
    document.getElementById('edit-extras-runs').value = exRuns;
    document.getElementById('edit-wicket-type').value = wType || '';
    document.getElementById('modal-edit-ball').style.display = 'flex';
}

function setEditRun(r) { document.getElementById('edit-runs-input').value = r; }

async function submitEditBall() {
    const fd = new FormData();
    fd.append('ball_id', document.getElementById('edit-ball-id').value);
    fd.append('runs_bat', document.getElementById('edit-runs-input').value);
    fd.append('extras_type', document.getElementById('edit-extras-type').value);
    fd.append('extras_runs', document.getElementById('edit-extras-runs').value);
    const wType = document.getElementById('edit-wicket-type').value;
    if(wType) {
        fd.append('is_wicket', 1);
        fd.append('wicket_type', wType);
    } else {
        fd.append('is_wicket', 0);
    }
    await fetch('../api/ball_edit.php', { method:'POST', body:fd });
    document.getElementById('modal-edit-ball').style.display = 'none';
    refresh();
}

refresh();
const refreshRate = 5000;
refreshInterval = setInterval(refresh, refreshRate);
</script>
</body>
</html>