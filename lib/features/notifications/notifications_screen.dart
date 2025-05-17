import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, Map<String, dynamic>> _deletedNotifications = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final notifications = provider.notifications;

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications yet'),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isUnread = !notification['read'];

              return Dismissible(
                key: Key(notification['_id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (direction) async {
                  // Store the notification for potential undo
                  _deletedNotifications[notification['_id']] = notification;
                  
                  // Show undo snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification deleted'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          setState(() {
                            _deletedNotifications.remove(notification['_id']);
                          });
                        },
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  return true;
                },
                onDismissed: (direction) async {
                  await provider.deleteNotification(notification['_id']);
                  _deletedNotifications.remove(notification['_id']);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(notification['type']),
                    child: Icon(
                      _getNotificationIcon(notification['type']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    notification['title'],
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification['message']),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(notification['createdAt']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: isUnread
                      ? IconButton(
                          icon: const Icon(Icons.mark_email_read),
                          onPressed: () {
                            provider.markAsRead(notification['_id']);
                          },
                        )
                      : null,
                  onTap: () {
                    if (isUnread) {
                      provider.markAsRead(notification['_id']);
                    }
                    // TODO: Navigate to appropriate screen based on notification type
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'offer':
        return Colors.blue;
      case 'match':
        return Colors.green;
      case 'message':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'offer':
        return Icons.swap_horiz;
      case 'match':
        return Icons.favorite;
      case 'message':
        return Icons.message;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }
} 