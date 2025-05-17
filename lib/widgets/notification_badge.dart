import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

class NotificationBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? badgeColor;
  final Color? textColor;

  const NotificationBadge({
    Key? key,
    this.onTap,
    this.badgeColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;
        
        if (unreadCount == 0) {
          return IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: onTap,
          );
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: onTap,
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: badgeColor ?? Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
} 