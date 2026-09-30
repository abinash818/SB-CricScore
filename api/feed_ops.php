<?php
// api/feed_ops.php
// Cricket Community Feed API (Pure MySQL)
// GET  /api/feed_ops.php?action=list&category=all|highlights|match_finder
// POST /api/feed_ops.php?action=create (with optional photo & whatsapp)
// POST /api/feed_ops.php?action=like
// POST /api/feed_ops.php?action=delete

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Auto-create & migrate feed tables (MySQL)
try {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS feed_posts (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            user_id         INT NOT NULL DEFAULT 0,
            content         TEXT NOT NULL,
            image_url       VARCHAR(255) DEFAULT NULL,
            match_id        INT DEFAULT NULL,
            post_type       VARCHAR(50) NOT NULL DEFAULT 'general',
            whatsapp_number VARCHAR(30) DEFAULT NULL,
            likes_count     INT DEFAULT 0,
            comments_count  INT DEFAULT 0,
            created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_feed_user (user_id),
            INDEX idx_feed_type (post_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

        CREATE TABLE IF NOT EXISTS feed_likes (
            post_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (post_id, user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

        CREATE TABLE IF NOT EXISTS feed_comments (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            post_id    INT NOT NULL,
            user_id    INT NOT NULL,
            comment    TEXT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_comment_post (post_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");

    $cols = $pdo->query("SHOW COLUMNS FROM feed_posts")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('post_type', $cols)) $pdo->exec("ALTER TABLE feed_posts ADD COLUMN post_type VARCHAR(50) DEFAULT 'general'");
    if (!in_array('whatsapp_number', $cols)) $pdo->exec("ALTER TABLE feed_posts ADD COLUMN whatsapp_number VARCHAR(30) DEFAULT NULL");
} catch (Throwable $e) {}

$action = $_GET['action'] ?? ($_POST['action'] ?? 'list');

// ── 1. GET COMMUNITY FEED POSTS ─────────────────────────────────────────────
if ($action === 'list') {
    $currentUser   = app_optional_auth($pdo);
    $currentUserId = $currentUser ? (int)$currentUser['id'] : 0;
    $category      = trim($_GET['category'] ?? 'all');
    $page          = max(1, (int)($_GET['page'] ?? 1));
    $limit         = 20;
    $offset        = ($page - 1) * $limit;

    $where = [];
    $params = [];

    if ($category === 'highlights') {
        $where[] = "p.post_type = 'highlight'";
    } elseif ($category === 'match_finder') {
        $where[] = "p.post_type = 'match_finder'";
    } elseif ($category === 'general') {
        $where[] = "p.post_type = 'general'";
    }

    $whereClause = !empty($where) ? "WHERE " . implode(' AND ', $where) : "";

    $stmt = $pdo->prepare("
        SELECT p.*, 
               COALESCE(u.name, 'SB CricScore Official') as author_name, 
               COALESCE(u.city, 'India') as author_city, 
               u.profile_pic as author_pic,
               u.role as author_role
        FROM feed_posts p
        LEFT JOIN app_users u ON u.id = p.user_id
        {$whereClause}
        ORDER BY p.id DESC
        LIMIT ? OFFSET ?
    ");
    
    // Bind limit & offset as integers for MySQL
    $paramIdx = 1;
    foreach ($params as $p) {
        $stmt->bindValue($paramIdx++, $p);
    }
    $stmt->bindValue($paramIdx++, $limit, PDO::PARAM_INT);
    $stmt->bindValue($paramIdx++, $offset, PDO::PARAM_INT);
    $stmt->execute();
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Fetch likes set for logged in user
    $userLikedPostIds = [];
    if ($currentUserId > 0) {
        $likesStmt = $pdo->prepare("SELECT post_id FROM feed_likes WHERE user_id = ?");
        $likesStmt->execute([$currentUserId]);
        $userLikedPostIds = array_flip($likesStmt->fetchAll(PDO::FETCH_COLUMN));
    }

    $out = [];
    foreach ($posts as $p) {
        $postId  = (int)$p['id'];
        $isLiked = isset($userLikedPostIds[$postId]);

        $out[] = [
            'id'              => $postId,
            'user_id'         => (int)$p['user_id'],
            'author_name'     => $p['author_name'],
            'author_city'     => $p['author_city'],
            'author_pic'      => $p['author_pic'],
            'author_role'     => $p['author_role'] ?? 'Cricketer',
            'content'         => $p['content'],
            'image_url'       => $p['image_url'],
            'post_type'       => $p['post_type'] ?? 'general',
            'whatsapp_number' => $p['whatsapp_number'] ?? '',
            'likes_count'     => (int)$p['likes_count'],
            'comments_count'  => (int)$p['comments_count'],
            'is_liked'        => $isLiked,
            'is_author'       => ($currentUserId > 0 && (int)$p['user_id'] === $currentUserId),
            'created_at'      => $p['created_at'],
        ];
    }

    echo json_encode([
        'success'  => true,
        'category' => $category,
        'page'     => $page,
        'posts'    => $out
    ]);
    exit;
}

// ── 2. CREATE POST ──────────────────────────────────────────────────────────
if ($action === 'create') {
    $user   = app_require_auth($pdo);
    $userId = (int)$user['id'];

    $content   = trim($_POST['content'] ?? (json_decode(file_get_contents('php://input'), true)['content'] ?? ''));
    $postType  = trim($_POST['post_type'] ?? (json_decode(file_get_contents('php://input'), true)['post_type'] ?? 'general'));
    $whatsapp  = trim($_POST['whatsapp_number'] ?? (json_decode(file_get_contents('php://input'), true)['whatsapp_number'] ?? ''));

    if (empty($content)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Post message cannot be empty.']);
        exit;
    }

    if (!in_array($postType, ['general', 'match_finder', 'highlight'], true)) {
        $postType = 'general';
    }

    if (empty($whatsapp) && $postType === 'match_finder') {
        $whatsapp = $user['mobile'] ?? '';
    }

    $imagePath = null;
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $fileTmp  = $_FILES['image']['tmp_name'];
        $fileName = $_FILES['image']['name'];
        $ext      = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));

        if (in_array($ext, ['jpg', 'jpeg', 'png', 'webp'])) {
            $uploadDir = __DIR__ . '/../uploads/feed/';
            if (!is_dir($uploadDir)) @mkdir($uploadDir, 0775, true);

            $newFile     = 'feed_' . $userId . '_' . time() . '.jpg';
            $destination = $uploadDir . $newFile;

            // Compress image with GD (Max 600x600, ~35-45KB size)
            $img = null;
            if ($ext === 'png') $img = @imagecreatefrompng($fileTmp);
            elseif ($ext === 'webp') $img = @imagecreatefromwebp($fileTmp);
            else $img = @imagecreatefromjpeg($fileTmp);

            if ($img) {
                $origW = imagesx($img);
                $origH = imagesy($img);
                $maxDim = 600;
                if ($origW > $maxDim || $origH > $maxDim) {
                    $ratio = min($maxDim / $origW, $maxDim / $origH);
                    $newW = (int)($origW * $ratio);
                    $newH = (int)($origH * $ratio);
                    $resized = imagecreatetruecolor($newW, $newH);
                    imagecopyresampled($resized, $img, 0, 0, 0, 0, $newW, $newH, $origW, $origH);
                    imagedestroy($img);
                    $img = $resized;
                }
                imagejpeg($img, $destination, 80);
                imagedestroy($img);
                $imagePath = 'uploads/feed/' . $newFile;
            }
        }
    }

    $stmt = $pdo->prepare("
        INSERT INTO feed_posts (user_id, content, image_url, post_type, whatsapp_number) 
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->execute([$userId, $content, $imagePath, $postType, $whatsapp]);
    $postId = (int)$pdo->lastInsertId();

    echo json_encode([
        'success'   => true, 
        'message'   => 'Post published to Cricket Community! 🎉',
        'post_id'   => $postId
    ]);
    exit;
}

// ── 3. LIKE / UNLIKE POST ───────────────────────────────────────────────────
if ($action === 'like') {
    $user   = app_require_auth($pdo);
    $userId = (int)$user['id'];

    $input  = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $postId = (int)($input['post_id'] ?? 0);

    if ($postId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid post ID.']);
        exit;
    }

    $check = $pdo->prepare("SELECT COUNT(*) FROM feed_likes WHERE post_id=? AND user_id=?");
    $check->execute([$postId, $userId]);
    $alreadyLiked = ((int)$check->fetchColumn()) > 0;

    if ($alreadyLiked) {
        // Unlike
        $pdo->prepare("DELETE FROM feed_likes WHERE post_id=? AND user_id=?")->execute([$postId, $userId]);
        $pdo->prepare("UPDATE feed_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id=?")->execute([$postId]);
        echo json_encode(['success' => true, 'liked' => false, 'message' => 'Unliked']);
    } else {
        // Like
        $pdo->prepare("INSERT INTO feed_likes (post_id, user_id) VALUES (?, ?)")->execute([$postId, $userId]);
        $pdo->prepare("UPDATE feed_posts SET likes_count = likes_count + 1 WHERE id=?")->execute([$postId]);
        echo json_encode(['success' => true, 'liked' => true, 'message' => 'Liked ❤️']);
    }
    exit;
}

// ── 4. DELETE POST ──────────────────────────────────────────────────────────
if ($action === 'delete') {
    $user   = app_require_auth($pdo);
    $userId = (int)$user['id'];

    $input  = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $postId = (int)($input['post_id'] ?? 0);

    if ($postId <= 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid post ID']);
        exit;
    }

    $st = $pdo->prepare("SELECT image_url, user_id FROM feed_posts WHERE id = ?");
    $st->execute([$postId]);
    $post = $st->fetch();

    if (!$post || (int)$post['user_id'] !== $userId) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Unauthorized to delete this post.']);
        exit;
    }

    if (!empty($post['image_url'])) {
        $imgPath = __DIR__ . '/../' . $post['image_url'];
        if (file_exists($imgPath)) @unlink($imgPath);
    }

    $pdo->prepare("DELETE FROM feed_posts WHERE id = ?")->execute([$postId]);
    $pdo->prepare("DELETE FROM feed_likes WHERE post_id = ?")->execute([$postId]);
    $pdo->prepare("DELETE FROM feed_comments WHERE post_id = ?")->execute([$postId]);

    echo json_encode(['success' => true, 'message' => 'Post deleted successfully.']);
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);
