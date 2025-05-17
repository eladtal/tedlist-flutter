import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  WebSocketChannel? _channel;
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(initializationSettings);

    // Request notification permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      // TODO: Send token to backend
      print('FCM Token: $token');
    }

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Initialize WebSocket connection
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      final token = prefs.getString('auth_token');
      if (token != null) {
        final wsUrl = Uri.parse('ws://your-backend-url/ws?token=$token');
        _channel = IOWebSocketChannel.connect(wsUrl);
        _channel?.stream.listen(
          (message) {
            final data = json.decode(message);
            if (data['type'] == 'notification') {
              _notificationController.add(data['data']);
              _incrementUnreadCount();
              _showLocalNotification(data['data']);
            }
          },
          onError: (error) {
            print('WebSocket error: $error');
            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 5), _initializeWebSocket);
          },
          onDone: () {
            print('WebSocket connection closed');
            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 5), _initializeWebSocket);
          },
        );
      }
    });
  }

  void _incrementUnreadCount() {
    _unreadCount++;
    _unreadCountController.add(_unreadCount);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      // TODO: Call API to mark notification as read
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      _unreadCountController.add(_unreadCount);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notification) async {
    if (!kIsWeb) {
      const androidDetails = AndroidNotificationDetails(
        'tedlist_notifications',
        'Tedlist Notifications',
        channelDescription: 'Notifications from Tedlist',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification['_id'].hashCode,
        notification['title'],
        notification['message'],
        details,
        payload: json.encode(notification),
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Handling foreground message: ${message.messageId}');
    // Show local notification
    _showLocalNotification({
      '_id': message.messageId,
      'title': message.notification?.title ?? 'New Notification',
      'message': message.notification?.body ?? '',
    });
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling background message: ${message.messageId}');
    // TODO: Navigate to appropriate screen based on notification type
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // TODO: Call API to delete notification
      // For now, we'll just remove it from the local state
      _notificationController.add({
        'type': 'delete',
        'notificationId': notificationId,
      });
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  void dispose() {
    _channel?.sink.close();
    _notificationController.close();
    _unreadCountController.close();
  }
} 