import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'storage_service.dart';
import 'api_service.dart';
import '../screens/stock_recommendation_screen.dart';

/// Top-level background message handler executed in background isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId} - ${message.data}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;

  bool get isFirebaseAvailable => _isFirebaseAvailable;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'stock_intelligence_alerts',
    'Stock Intelligence Alerts',
    description: 'High-priority stock breakout and risk management alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initializes Firebase and notification listeners with graceful local fallback
  Future<void> initialize({required ApiService apiService}) async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase if possible
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        _isFirebaseAvailable = true;
        debugPrint('Firebase Core initialized successfully.');
      } catch (fbInitError) {
        debugPrint('Firebase initialization skipped/failed: $fbInitError. Running in local alert mode.');
        _isFirebaseAvailable = false;
      }

      // 2. Configure Local Notifications Plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handlePayload(payload);
          }
        },
      );

      // Create notification channel for Android 8.0+
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 3. Configure FCM if Firebase is active
      if (_isFirebaseAvailable) {
        final messaging = FirebaseMessaging.instance;

        // Request user permissions (Android 13+ / iOS)
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('Notification permission status: ${settings.authorizationStatus}');

        // Register background handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Fetch & register FCM Device Token
        try {
          final token = await messaging.getToken();
          if (token != null && token.isNotEmpty) {
            await StorageService.setFcmToken(token);
            debugPrint('FCM Token retrieved: ${token.substring(0, 10)}...');
            // Register with backend
            await apiService.registerDeviceToken(token);
          }
        } catch (tokenError) {
          debugPrint('Error fetching FCM device token: $tokenError');
        }

        // Listen for token updates
        messaging.onTokenRefresh.listen((newToken) async {
          await StorageService.setFcmToken(newToken);
          await apiService.registerDeviceToken(newToken);
        });

        // Foreground push message listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground message received: ${message.notification?.title}');
          _showLocalNotification(message);
        });

        // App opened from background by tapping notification
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('App opened from notification: ${message.data}');
          _handleMessageData(message.data);
        });

        // Check if opened from terminated state
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageData(initialMessage.data);
          });
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization exception: $e');
    }
  }

  /// Displays foreground head-up notification via Local Notifications
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'AI Stock Intelligence Alert';
    final body = notification?.body ?? message.data['body'] ?? 'Review latest stock recommendation.';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }

  /// Routes to relevant screen when alert is tapped
  void _handlePayload(String payloadJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(payloadJson);
      _handleMessageData(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final symbol = data['symbol'] as String?;
    final exchange = (data['exchange'] as String?) ?? 'NSE';

    if (symbol != null && symbol.isNotEmpty) {
      debugPrint('Navigating to recommendation for $symbol...');
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => StockRecommendationScreen(
            symbol: symbol,
            exchange: exchange,
          ),
        ),
      );
    }
  }
}
