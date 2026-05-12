import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart' as notif_model;

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
    return ListTile(
      tileColor: notification.isRead ? null : Colors.blue.withOpacity(0.04),
      title: Text(notification.message),
      subtitle: Text('${notification.username} • ${notification.timestamp}'),
      trailing: notification.isRead
          ? null
          : TextButton(
              onPressed: () => context.read<NotificationService>().markAsRead(
                notification.id,
              ),
              child: const Text('Mark'),
            ),
      onTap: () {
        context.read<NotificationService>().markAsRead(notification.id);
      },
    );
  }
}
