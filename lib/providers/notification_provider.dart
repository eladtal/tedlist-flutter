import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen to notification stream
    _notificationService.notificationStream.listen((notification) {
      if (notification['type'] == 'delete') {
        _notifications.removeWhere((n) => n['_id'] == notification['notificationId']);
        notifyListeners();
      } else {
        _notifications.insert(0, notification);
        notifyListeners();
      }
    });

    // Listen to unread count stream
    _notificationService.unreadCountStream.listen((count) {
      _unreadCount = count;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    final index = _notifications.indexWhere((n) => n['_id'] == notificationId);
    if (index != -1) {
      _notifications[index]['read'] = true;
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
    final index = _notifications.indexWhere((n) => n['_id'] == notificationId);
    if (index != -1) {
      final wasUnread = !_notifications[index]['read'];
      _notifications.removeAt(index);
      if (wasUnread) {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
} 