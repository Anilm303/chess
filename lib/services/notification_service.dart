import 'package:flutter/material.dart';
import '../models/notification_model.dart' as notif_model;
import 'auth_service.dart';
import 'call_service.dart';

class NotificationService extends ChangeNotifier {
  final AuthService authService;
  final CallService callService;
  final List<notif_model.Notification> _notifications = [];
  bool _isLoading = false;

  NotificationService({required this.authService, required this.callService}) {
    _setupSocketListeners();
    // Watch callService for socket becoming available
    callService.addListener(_maybeAttachSocketListeners);
  }

  List<notif_model.Notification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  /// Setup Socket.IO listeners for real-time notifications
  void _setupSocketListeners() {
    // Attach listeners only if socket available
    final socket = callService.socket;
    if (socket == null) return;

    // Listen for story reactions
    socket.on('story_reaction', (data) {
      _addNotification(
        username: data['username'] ?? '',
        type: 'story_reaction',
        message: 'reacted to your story',
        timestamp: DateTime.now(),
      );
    });

    // Listen for note reactions
    socket.on('note_reaction', (data) {
      _addNotification(
        username: data['username'] ?? '',
        type: 'note_reaction',
        message: 'reacted to your note',
        timestamp: DateTime.now(),
      );
    });

    socket.on('missed_call', (data) {
      _addNotification(
        username: data['username'] ?? data['callee_username'] ?? '',
        type: 'missed_call',
        message: 'missed your call',
        timestamp: DateTime.now(),
      );
    });

    socket.on('call_declined', (data) {
      _addNotification(
        username: data['username'] ?? data['callee_username'] ?? '',
        type: 'call_declined',
        message: 'declined your call',
        timestamp: DateTime.now(),
      );
    });
  }

  bool _socketListenersAttached = false;

  void _maybeAttachSocketListeners() {
    if (_socketListenersAttached) return;
    if (callService.socket != null) {
      _socketListenersAttached = true;
      _setupSocketListeners();
    }
  }

  /// Add a notification to the list
  void _addNotification({
    required String username,
    required String type,
    required String message,
    required DateTime timestamp,
  }) {
    final notification = notif_model.Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      type: type,
      message: message,
      timestamp: timestamp,
      isRead: false,
    );

    _notifications.insert(0, notification); // Add to top (most recent first)
    notifyListeners();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();

      // Send to backend (optional - for persistence)
      callService.socket?.emit('mark_notification_read', {
        'notificationId': notificationId,
      });
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    bool anyChanged = false;
    for (var notification in _notifications) {
      if (!notification.isRead) {
        notification.isRead = true;
        anyChanged = true;
      }
    }
    if (anyChanged) {
      notifyListeners();
      callService.socket?.emit('mark_all_notifications_read', {});
    }
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Remove a specific notification
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Load notifications from backend (on app startup)
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      // This would be called when app starts to sync notifications
      // For now, we rely on real-time Socket.IO events
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Error loading notifications: $e');
    }
  }

  @override
  void dispose() {
    try {
      callService.removeListener(_maybeAttachSocketListeners);
    } catch (_) {}
    super.dispose();
  }
}
