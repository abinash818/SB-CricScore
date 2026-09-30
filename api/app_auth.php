<?php
// api/app_auth.php
// Flutter app token-based authentication middleware
// Include this in any API that requires Flutter app login
//
// Usage:
//   require_once __DIR__ . '/../api/app_auth.php';
//   $appUser = app_require_auth($pdo);  // returns user array or exits with 401
//
// Flutter must send: Authorization: Bearer <token>

if (!function_exists('app_get_token')) {

    /**
     * Extract Bearer token from Authorization header
     */
    function app_get_token(): ?string {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (empty($header) && function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                foreach ($headers as $k => $v) {
                    if (strtolower($k) === 'authorization') {
                        $header = $v;
                        break;
                    }
                }
            }
        }
        if (preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
            return trim($m[1]);
        }
        // Also allow token in query string or post body for WebSocket / SSE / form fallbacks
        return $_GET['token'] ?? ($_POST['token'] ?? null);
    }

    /**
     * Validate token and return app_user row.
     * Exits with 401 JSON if token is invalid/expired.
     */
    function app_require_auth(PDO $pdo): array {
        $token = app_get_token();

        if (!$token) {
            http_response_code(401);
            echo json_encode(['success' => false, 'message' => 'Authentication required. Please login.']);
            exit;
        }

        $now = date('Y-m-d H:i:s');
        $stmt = $pdo->prepare("
            SELECT u.*, t.expires_at as token_expires
            FROM api_tokens t
            JOIN app_users u ON u.id = t.user_id
            WHERE t.token = ?
              AND t.expires_at >= ?
        ");
        $stmt->execute([$token, $now]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            http_response_code(401);
            echo json_encode(['success' => false, 'message' => 'Session expired. Please login again.', 'code' => 'TOKEN_EXPIRED']);
            exit;
        }

        if ((int)($user['is_blocked'] ?? 0) === 1) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Your account has been suspended.']);
            exit;
        }

        return $user;
    }

    /**
     * Optional auth — returns user or null (for public endpoints that show extra data when logged in)
     */
    function app_optional_auth(PDO $pdo): ?array {
        $token = app_get_token();
        if (!$token) return null;

        try {
            return app_require_auth($pdo);
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * Logout — revoke current token
     */
    function app_logout(PDO $pdo): void {
        $token = app_get_token();
        if ($token) {
            $pdo->prepare("DELETE FROM api_tokens WHERE token=?")->execute([$token]);
        }
    }
}
