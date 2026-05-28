import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/friend_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../models/notification_model.dart' as notif_model;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () =>
                context.read<NotificationService>().markAllAsRead(),
            child: const Text(
              'Mark all',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, svc, _) {
          final items = svc.notifications;
          if (items.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final notif = items[i];
              return NotificationTile(notification: notif);
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final notif_model.Notification notification;

  const NotificationTile({required this.notification, super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final friendService = context.read<FriendService>();
    final notificationService = context.read<NotificationService>();

    return ListTile(
      tileColor:
          notification.isRead ? null : Colors.blue.withValues(alpha: 0.04),
      title: Text(notification.message),
      subtitle: Text('${notification.username} • ${notification.timestamp}'),
      trailing: notification.type == 'friend_request'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final token = authService.accessToken;
                    if (token == null) return;
                    final ok = await friendService.respondRequest(
                      token,
                      notification.username,
                      false,
                    );
                    if (ok) {
                      await notificationService.markAsRead(notification.id);
                      notificationService.removeNotification(notification.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Friend request declined'
                                : 'Failed: ${friendService.error}',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Decline'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final token = authService.accessToken;
                    if (token == null) return;
                    final ok = await friendService.respondRequest(
                      token,
                      notification.username,
                      true,
                    );
                    if (ok) {
                      await notificationService.markAsRead(notification.id);
                      notificationService.removeNotification(notification.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Friend request accepted'
                                : 'Failed: ${friendService.error}',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Accept'),
                ),
              ],
            )
          : notification.isRead
              ? null
              : TextButton(
                  onPressed: () =>
                      notificationService.markAsRead(notification.id),
                  child: const Text('Mark'),
                ),
      onTap: () {
        notificationService.markAsRead(notification.id);
      },
    );
  }
}
