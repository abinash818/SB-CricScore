<?php
// api/fcm_send.php
// Send Firebase Cloud Messaging Push Notifications via FCM HTTP v1 API
// POST /api/fcm_send.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: POST, OPTIONS');

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/app_auth.php';

// Generate Google OAuth2 Access Token using Service Account JSON
function getGoogleAccessToken($credFile) {
    if (!file_exists($credFile)) {
        throw new Exception("FCM Credentials file missing: $credFile");
    }

    $json = json_decode(file_get_contents($credFile), true);
    if (!$json || !isset($json['private_key'])) {
        throw new Exception("Invalid FCM Credentials JSON format");
    }

    $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
    $now = time();
    $claim = json_encode([
        'iss'   => $json['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'exp'   => $now + 3600,
        'iat'   => $now
    ]);

    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlClaim  = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($claim));

    $signatureInput = $base64UrlHeader . "." . $base64UrlClaim;

    $privateKey = $json['private_key'];
    openssl_sign($signatureInput, $rawSignature, $privateKey, OPENSSL_ALGO_SHA256);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($rawSignature));

    $jwt = $signatureInput . "." . $base64UrlSignature;

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion'  => $jwt
    ]));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    curl_close($ch);

    $tokenData = json_decode($response, true);
    if (!isset($tokenData['access_token'])) {
        throw new Exception("Failed to get Google Access Token: " . ($tokenData['error_description'] ?? $response));
    }

    return $tokenData['access_token'];
}

// Function to send FCM message
function sendFcmNotification($token, $title, $body, $data = []) {
    $credFile = __DIR__ . '/fcm_credentials.json';
    $json = json_decode(file_get_contents($credFile), true);
    $projectId = $json['project_id'] ?? 'sbcricscore';

    $accessToken = getGoogleAccessToken($credFile);

    $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

    $payload = [
        'message' => [
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body'  => $body,
            ],
            'data' => (object)$data,
        ]
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json'
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $result = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return ['http_code' => $httpCode, 'response' => json_decode($result, true)];
}

// Handler if called directly
if (basename($_SERVER['PHP_SELF']) === 'fcm_send.php') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $title = trim($input['title'] ?? 'SB CricScore Alert 🏏');
    $body  = trim($input['body'] ?? 'Live Match Update!');
    $targetToken = trim($input['token'] ?? '');

    try {
        if (!empty($targetToken)) {
            $res = sendFcmNotification($targetToken, $title, $body, $input['data'] ?? []);
            echo json_encode(['success' => true, 'result' => $res]);
        } else {
            // Broadcast to all registered tokens
            $stmt = $pdo->query("SELECT fcm_token FROM fcm_tokens ORDER BY id DESC LIMIT 500");
            $tokens = $stmt->fetchAll(PDO::FETCH_COLUMN);

            $results = [];
            foreach ($tokens as $t) {
                if (!empty($t)) {
                    $results[] = sendFcmNotification($t, $title, $body, $input['data'] ?? []);
                }
            }
            echo json_encode(['success' => true, 'total_sent' => count($results), 'results' => $results]);
        }
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    }
}
