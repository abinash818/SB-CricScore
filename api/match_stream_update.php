<?php
// api/match_stream_update.php
// Update YouTube Live Streaming URL & State for a match
// POST { "match_id": 1, "youtube_url": "https://youtu.be/xxxx", "is_active": 1 }

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

$input       = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$matchId     = (int)($input['match_id'] ?? 0);
$youtubeUrl  = trim($input['youtube_url'] ?? ($input['youtube_live_url'] ?? ''));
$isActive    = isset($input['is_active']) ? (int)$input['is_active'] : (!empty($youtubeUrl) ? 1 : 0);

if ($matchId <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'match_id is required']);
    exit;
}

// Function to extract YouTube Video ID
function extract_youtube_id($url) {
    if (empty($url)) return null;
    $pattern = '%(?:youtube(?:-nocookie)?\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=|live/)|youtu\.be/)([^"&?/ ]{11})%i';
    if (preg_match($pattern, $url, $match)) {
        return $match[1];
    }
    // If it's already an 11-char video ID
    if (preg_match('/^[a-zA-Z0-9_-]{11}$/', $url)) {
        return $url;
    }
    return null;
}

$videoId = extract_youtube_id($youtubeUrl);
if (!empty($youtubeUrl) && !$videoId) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid YouTube Live URL or Video ID format.']);
    exit;
}

try {
    $stmt = $pdo->prepare("
        UPDATE matches 
        SET youtube_live_url = ?, 
            is_stream_active = ? 
        WHERE id = ?
    ");
    $stmt->execute([$youtubeUrl, $isActive, $matchId]);

    echo json_encode([
        'success'          => true,
        'message'          => $isActive ? 'YouTube Live stream activated!' : 'YouTube Live stream turned off.',
        'match_id'         => $matchId,
        'youtube_url'      => $youtubeUrl,
        'youtube_video_id' => $videoId,
        'is_active'        => (bool)$isActive,
        'embed_url'        => $videoId ? "https://www.youtube.com/embed/{$videoId}?autoplay=1" : null
    ]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
