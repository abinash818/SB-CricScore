<?php
// api/team_helpers.php
// Shared helper functions for team management, squad builder, and role permissions

if (!function_exists('get_team_user_role')) {
    function get_team_user_role(PDO $pdo, int $teamId, ?array $currentUser): array {
        if (!$currentUser || empty($currentUser['id'])) {
            return [
                'is_owner'          => false,
                'is_leader'         => false,
                'is_co_leader'      => false,
                'is_member'         => false,
                'can_manage_team'   => false,
                'can_manage_roles'  => false,
                'can_add_players'   => false,
                'can_remove_players'=> false,
                'viewer_role'       => 'guest'
            ];
        }

        $tStmt = $pdo->prepare("SELECT owner_id FROM teams WHERE id = ?");
        $tStmt->execute([$teamId]);
        $ownerId = (int)$tStmt->fetchColumn();

        $isOwner = (!empty($ownerId) && (int)$currentUser['id'] === $ownerId);

        $userMobile = $currentUser['mobile'] ?? ($currentUser['phone'] ?? '');
        $cleanMobile = preg_replace('/\D+/', '', $userMobile);
        $last10 = (strlen($cleanMobile) >= 10) ? substr($cleanMobile, -10) : $cleanMobile;

        $userName = trim($currentUser['name'] ?? '');

        $isLeader = $isOwner;
        $isCoLeader = false;
        $isMember = false;

        $pRow = null;
        if (!empty($last10) && strlen($last10) >= 7) {
            $pStmt = $pdo->prepare("SELECT id, name, is_captain, team_role FROM players WHERE team_id = ? AND (mobile = ? OR mobile = ? OR mobile = ? OR mobile LIKE ?) LIMIT 1");
            $pStmt->execute([$teamId, $userMobile, '+91' . $last10, $last10, '%' . $last10]);
            $pRow = $pStmt->fetch(PDO::FETCH_ASSOC);
        }
        if (!$pRow && !empty($userName) && strlen($userName) >= 2) {
            $pStmt = $pdo->prepare("SELECT id, name, is_captain, team_role FROM players WHERE team_id = ? AND LOWER(TRIM(name)) = ? LIMIT 1");
            $pStmt->execute([$teamId, strtolower($userName)]);
            $pRow = $pStmt->fetch(PDO::FETCH_ASSOC);
        }

        if ($pRow) {
            $isMember = true;
            $r = strtolower($pRow['team_role'] ?? '');
            if ($r === 'leader' || (int)$pRow['is_captain'] === 1) {
                $isLeader = true;
            } else if ($r === 'co_leader') {
                $isCoLeader = true;
            }
        }

        // Auto-heal: If team has no owner assigned and user is the captain/leader, assign them as owner
        if (empty($ownerId) && $isLeader && !empty($currentUser['id'])) {
            $pdo->prepare("UPDATE teams SET owner_id = ? WHERE id = ?")->execute([(int)$currentUser['id'], $teamId]);
            $isOwner = true;
        }

        $canManageRoles = ($isLeader || $isOwner);
        $canManageTeam  = ($isLeader || $isCoLeader || $isOwner);

        return [
            'is_owner'          => $isOwner,
            'is_leader'         => $isLeader,
            'is_co_leader'      => $isCoLeader,
            'is_member'         => $isMember,
            'can_manage_team'   => $canManageTeam,
            'can_manage_roles'  => $canManageRoles,
            'can_add_players'   => $canManageTeam,
            'can_remove_players'=> $canManageTeam,
            'viewer_role'       => $isLeader ? 'leader' : ($isCoLeader ? 'co_leader' : ($isMember ? 'member' : ($isOwner ? 'owner' : 'guest')))
        ];
    }
}
