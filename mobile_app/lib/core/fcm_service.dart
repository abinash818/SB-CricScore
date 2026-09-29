import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('FCM Background message received: ${message.messageId}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final ApiService _apiService = ApiService();

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      
      // Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Notification permissions
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('FCM Notification permission granted.');
      }

      // Get FCM Token
      String? token = await messaging.getToken();
      if (token != null) {
        log('FCM Token: $token');
        await _registerTokenWithBackend(token);
      }

      // Token refresh listener
      messaging.onTokenRefresh.listen((newToken) {
        _registerTokenWithBackend(newToken);
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('FCM Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      });
    } catch (e) {
      log('FCM Initialization error: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiService.dio.post(
        '/fcm_token_register.php',
        data: {'fcm_token': token, 'device_type': 'android'},
      );
    } catch (e) {
      log('FCM Token registration error: $e');
    }
  }
}
