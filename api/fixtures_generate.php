<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/auth.php';
require_login($pdo);
header('Content-Type: application/json');

$tournament_id = (int)($_POST['tournament_id'] ?? 0);
$overs = (int)($_POST['overs_limit'] ?? 20);
$type = $_POST['type'] ?? ''; // 'group', 'single', 'double', 'knockout'

if ($tournament_id <= 0) { http_response_code(400); echo json_encode(['error'=>'tournament_id required']); exit; }

$tour = $pdo->prepare("SELECT * FROM tournaments WHERE id=?");
$tour->execute([$tournament_id]);
$t = $tour->fetch(PDO::FETCH_ASSOC);
if (!$t) { http_response_code(404); echo json_encode(['error'=>'Tournament not found']); exit; }

// Fallback if type wasn't passed
if (empty($type)) {
    if ($t['type'] === 'knockout') $type = 'knockout';
    elseif ($t['type'] === 'group' || $t['type'] === 'groups') $type = 'group';
    else $type = 'single';
}

$teamsStmt = $pdo->prepare("SELECT id, name, group_name FROM teams WHERE tournament_id=? ORDER BY group_name ASC, name ASC");
$teamsStmt->execute([$tournament_id]);
$teams = $teamsStmt->fetchAll(PDO::FETCH_ASSOC);

if (count($teams) < 2) { http_response_code(400); echo json_encode(['error'=>'Add at least 2 teams to generate fixtures']); exit; }

$created = 0;

if ($type === 'group' || $type === 'groups') {
    // GROUP WISE ROUND ROBIN (Group A vs Group A, Group B vs Group B)
    $groupedTeams = [];
    foreach ($teams as $tm) {
        $grp = trim($tm['group_name'] ?? '');
        if (empty($grp)) $grp = 'Group A';
        $groupedTeams[$grp][] = $tm;
    }

    foreach ($groupedTeams as $grpName => $grpList) {
        if (count($grpList) < 2) continue;
        for ($i = 0; $i < count($grpList); $i++) {
            for ($j = $i + 1; $j < count($grpList); $j++) {
                $a = (int)$grpList[$i]['id'];
                $b = (int)$grpList[$j]['id'];
                $stmt = $pdo->prepare("INSERT INTO matches(tournament_id, team_a_id, team_b_id, overs_limit, status) VALUES(?,?,?,?, 'scheduled')");
                $stmt->execute([$tournament_id, $a, $b, $overs]);
                $created++;
            }
        }
    }
}
else if ($type === 'single') {
  // SINGLE ROUND ROBIN: Each team plays every other team ONCE
  for ($i=0; $i<count($teams); $i++) {
    for ($j=$i+1; $j<count($teams); $j++) {
      $a = (int)$teams[$i]['id'];
      $b = (int)$teams[$j]['id'];
      $stmt = $pdo->prepare("INSERT INTO matches(tournament_id, team_a_id, team_b_id, overs_limit, status) VALUES(?,?,?,?, 'scheduled')");
      $stmt->execute([$tournament_id, $a, $b, $overs]);
      $created++;
    }
  }
} 
else if ($type === 'double') {
  // DOUBLE ROUND ROBIN: Each team plays every other team TWICE (Home & Away)
  for ($i=0; $i<count($teams); $i++) {
    for ($j=0; $j<count($teams); $j++) {
      if ($i === $j) continue;
      $a = (int)$teams[$i]['id'];
      $b = (int)$teams[$j]['id'];
      $stmt = $pdo->prepare("INSERT INTO matches(tournament_id, team_a_id, team_b_id, overs_limit, status) VALUES(?,?,?,?, 'scheduled')");
      $stmt->execute([$tournament_id, $a, $b, $overs]);
      $created++;
    }
  }
}
else {
  // KNOCKOUT: Single elimination bracket
  $ids = array_map(fn($x)=> (int)$x['id'], $teams);
  $n = count($ids);
  $i = 0; $j = $n - 1;
  while ($i < $j) {
    $a = $ids[$i];
    $b = $ids[$j];
    $stmt = $pdo->prepare("INSERT INTO matches(tournament_id, team_a_id, team_b_id, overs_limit, status) VALUES(?,?,?,?, 'scheduled')");
    $stmt->execute([$tournament_id, $a, $b, $overs]);
    $created++;
    $i++; $j--;
  }
}

echo json_encode(['ok'=>true,'created'=>$created,'type'=>$type]);
?>