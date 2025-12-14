import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  /// Callback to re-register token with backend when it refreshes
  Future<void> Function(String token)? _onTokenRefresh;

  /// Initialize Firebase Messaging and local notifications
  Future<void> initialize() async {
    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission for iOS
      await _requestPermission();

      // Initialize local notifications for foreground messages
      await _initializeLocalNotifications();

      // Get FCM token
      await _getToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        // Re-register token with backend when refreshed
        if (_onTokenRefresh != null) {
          try {
            await _onTokenRefresh!(newToken);
            debugPrint('FCM Token re-registered with backend');
          } catch (e) {
            debugPrint('Failed to re-register FCM token: $e');
          }
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      debugPrint('Push notification service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing push notifications: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - let the app continue without push notifications
    }
  }

  /// Request notification permissions (primarily for iOS)
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  /// Initialize local notifications for showing notifications when app is in foreground
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
        // Handle notification tap
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'logopedy_notifications',
        'Logopedy Notifications',
        description: 'Notificări pentru aplicația Logopedy',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Get the FCM token
  Future<String?> _getToken() async {
    try {
      // On iOS, we need to wait for the APNS token before getting FCM token
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        
        // If APNS token is not available yet, wait and retry a few times
        if (apnsToken == null) {
          debugPrint('APNS token not available yet, waiting...');
          
          // Retry up to 5 times with increasing delays
          for (int i = 0; i < 5; i++) {
            await Future.delayed(Duration(seconds: 1 + i));
            apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null) break;
          }
          
          if (apnsToken == null) {
            debugPrint('APNS token not available. This is expected on iOS Simulator.');
            debugPrint('Push notifications require a physical iOS device.');
            // Token will be obtained later via onTokenRefresh on real devices
            return null;
          }
        }
        debugPrint('APNS Token available');
      }
      
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground messages by showing a local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.messageId}');
    
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'logopedy_notifications',
          'Logopedy Notifications',
          channelDescription: 'Notificări pentru aplicația Logopedy',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap when app is in background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');
    
    // Navigate based on notification type
    final type = message.data['type'];
    switch (type) {
      case 'practice_reminder':
        // Navigate to modules/lessons
        break;
      case 'premium_granted':
        // Navigate to premium content or show celebration
        break;
      case 'new_content':
        // Navigate to the new module/submodule
        final moduleId = message.data['moduleId'];
        if (moduleId != null) {
          // Navigate to module
        }
        break;
      default:
        // Default navigation
        break;
    }
  }

  /// Get a fresh token (useful for re-registration)
  Future<String?> getToken() async {
    return await _getToken();
  }

  /// Set callback to be called when token refreshes (call after user login)
  void setOnTokenRefresh(Future<void> Function(String token) callback) {
    _onTokenRefresh = callback;
  }

  /// Clear callback (call on logout)
  void clearOnTokenRefresh() {
    _onTokenRefresh = null;
  }
}
