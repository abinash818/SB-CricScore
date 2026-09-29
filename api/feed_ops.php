<?php
// api/feed_ops.php
// Cricket Community Feed API
// GET  /api/feed_ops.php?action=list -> Get social feed posts
// POST /api/feed_ops.php?action=create -> Create post with optional photo
// POST /api/feed_ops.php?action=like -> Like/Unlike post
// POST /api/feed_ops.php?action=comment -> Add comment to post

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);

// ── Auto-create feed tables if missing ──
if ($driver === 'sqlite') {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS feed_posts (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id      INTEGER NOT NULL,
            content      TEXT NOT NULL,
            image_url    TEXT DEFAULT NULL,
            match_id     INTEGER DEFAULT NULL,
            likes_count  INTEGER DEFAULT 0,
            comments_count INTEGER DEFAULT 0,
            created_at   TEXT NOT NULL DEFAULT (datetime('now'))
        );
        CREATE TABLE IF NOT EXISTS feed_likes (
            post_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            PRIMARY KEY (post_id, user_id)
        );
        CREATE TABLE IF NOT EXISTS feed_comments (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            post_id    INTEGER NOT NULL,
            user_id    INTEGER NOT NULL,
            comment    TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        );
    ");
} else {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS feed_posts (
            id             INT AUTO_INCREMENT PRIMARY KEY,
            user_id        INT NOT NULL,
            content        TEXT NOT NULL,
            image_url      VARCHAR(255) DEFAULT NULL,
            match_id       INT DEFAULT NULL,
            likes_count    INT DEFAULT 0,
            comments_count INT DEFAULT 0,
            created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS feed_likes (
            post_id INT NOT NULL,
            user_id INT NOT NULL,
            PRIMARY KEY (post_id, user_id)
        );
        CREATE TABLE IF NOT EXISTS feed_comments (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            post_id    INT NOT NULL,
            user_id    INT NOT NULL,
            comment    TEXT NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    ");
}

$action = $_GET['action'] ?? ($_POST['action'] ?? 'list');

// ── GET FEED POSTS ───────────────────────────────────────────────────────────
if ($action === 'list') {
    $currentUser = app_optional_auth($pdo);
    $currentUserId = $currentUser ? (int)$currentUser['id'] : 0;

    $stmt = $pdo->query("
        SELECT p.*, u.name as author_name, u.city as author_city, u.profile_pic as author_pic
        FROM feed_posts p
        LEFT JOIN app_users u ON u.id = p.user_id
        ORDER BY p.id DESC
        LIMIT 20
    ");
    $posts = $stmt->fetchAll();

    $out = [];
    foreach ($posts as $p) {
        $postId = (int)$p['id'];
        $isLiked = false;

        if ($currentUserId > 0) {
            $likeCheck = $pdo->prepare("SELECT COUNT(*) FROM feed_likes WHERE post_id=? AND user_id=?");
            $likeCheck->execute([$postId, $currentUserId]);
            $isLiked = ((int)$likeCheck->fetchColumn()) > 0;
        }

        $out[] = [
            'id'             => $postId,
            'user_id'        => (int)$p['user_id'],
            'author_name'    => $p['author_name'] ?: 'Cricketer',
            'author_city'    => $p['author_city'] ?: 'India',
            'author_pic'     => $p['author_pic'],
            'content'        => $p['content'],
            'image_url'      => $p['image_url'],
            'likes_count'    => (int)$p['likes_count'],
            'comments_count' => (int)$p['comments_count'],
            'is_liked'       => $isLiked,
            'created_at'     => $p['created_at'],
        ];
    }

    echo json_encode(['success' => true, 'posts' => $out]);
    exit;
}

// ── CREATE POST ──────────────────────────────────────────────────────────────
if ($action === 'create') {
    $user   = app_require_auth($pdo);
    $userId = (int)$user['id'];

    $content = trim($_POST['content'] ?? (json_decode(file_get_contents('php://input'), true)['content'] ?? ''));

    if (empty($content)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Post content cannot be empty.']);
        exit;
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

            // Compress image with GD
            $img = ($ext === 'png') ? @imagecreatefrompng($fileTmp) : (($ext === 'webp') ? @imagecreatefromwebp($fileTmp) : @imagecreatefromjpeg($fileTmp));
            if ($img) {
                imagejpeg($img, $destination, 80);
                imagedestroy($img);
                $imagePath = 'uploads/feed/' . $newFile;
            }
        }
    }

    $stmt = $pdo->prepare("INSERT INTO feed_posts (user_id, content, image_url) VALUES (?, ?, ?)");
    $stmt->execute([$userId, $content, $imagePath]);

    echo json_encode(['success' => true, 'message' => 'Post published successfully!']);
    exit;
}

// ── LIKE / UNLIKE POST ───────────────────────────────────────────────────────
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
        $pdo->prepare("UPDATE feed_posts SET likes_count = MAX(0, likes_count - 1) WHERE id=?")->execute([$postId]);
        echo json_encode(['success' => true, 'liked' => false, 'message' => 'Unliked post']);
    } else {
        // Like
        $pdo->prepare("INSERT INTO feed_likes (post_id, user_id) VALUES (?, ?)")->execute([$postId, $userId]);
        $pdo->prepare("UPDATE feed_posts SET likes_count = likes_count + 1 WHERE id=?")->execute([$postId]);
        echo json_encode(['success' => true, 'liked' => true, 'message' => 'Liked post']);
    }
    exit;
}

http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Invalid action']);
