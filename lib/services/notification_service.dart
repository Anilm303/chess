import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart' as notif_model;
import 'api_service.dart';
import 'auth_service.dart';
import 'call_service.dart';

class NotificationService extends ChangeNotifier {
  final AuthService authService;
  final CallService callService;
  final List<notif_model.Notification> _notifications = [];
  bool _isLoading = false;
  Timer? _friendRequestSyncTimer;

  NotificationService({required this.authService, required this.callService}) {
    _setupSocketListeners();
    // Watch callService for socket becoming available
    callService.addListener(_maybeAttachSocketListeners);
    authService.addListener(_handleAuthStateChange);
    _handleAuthStateChange();
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

    socket.on('friend_request', (data) {
      final username = data['from'] ?? data['username'] ?? '';
      if (username.toString().isEmpty) return;
      _addNotification(
        username: username.toString(),
        type: 'friend_request',
        message: 'sent you a friend request',
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

  void _handleAuthStateChange() {
    final token = authService.accessToken;
    if (authService.isAuthenticated && token != null && token.isNotEmpty) {
      _friendRequestSyncTimer ??= Timer.periodic(
        const Duration(seconds: 12),
        (_) => _syncPendingFriendRequests(),
      );
      _syncPendingFriendRequests();
      return;
    }
    _friendRequestSyncTimer?.cancel();
    _friendRequestSyncTimer = null;
  }

  Future<void> _syncPendingFriendRequests() async {
    final token = authService.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final url = '${ApiService.baseUrl}/friends/requests';
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiService.timeout);

      if (resp.statusCode != 200) return;

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final pending = (body['requests'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toSet();

      bool changed = false;

      // Remove stale friend-request notifications that are no longer pending.
      final staleIds = _notifications
          .where(
            (n) => n.type == 'friend_request' && !pending.contains(n.username),
          )
          .map((n) => n.id)
          .toList();
      if (staleIds.isNotEmpty) {
        _notifications.removeWhere((n) => staleIds.contains(n.id));
        changed = true;
      }

      // Add new pending friend requests not yet visible in notifications.
      for (final username in pending) {
        final exists = _notifications.any(
          (n) => n.type == 'friend_request' && n.username == username,
        );
        if (!exists) {
          _notifications.insert(
            0,
            notif_model.Notification(
              id: 'friend_req_${username}_${DateTime.now().millisecondsSinceEpoch}',
              username: username,
              type: 'friend_request',
              message: 'sent you a friend request',
              timestamp: DateTime.now(),
              isRead: false,
            ),
          );
          changed = true;
        }
      }

      if (changed) notifyListeners();
    } catch (_) {}
  }

  /// Add a notification to the list
  void _addNotification({
    required String username,
    required String type,
    required String message,
    required DateTime timestamp,
  }) {
    if (type == 'friend_request') {
      final alreadyExists = _notifications.any(
        (n) => n.type == 'friend_request' && n.username == username,
      );
      if (alreadyExists) return;
    }

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
      debugPrint('Error loading notifications: $e');
    }
  }

  @override
  void dispose() {
    try {
      callService.removeListener(_maybeAttachSocketListeners);
    } catch (_) {}
    try {
      authService.removeListener(_handleAuthStateChange);
    } catch (_) {}
    _friendRequestSyncTimer?.cancel();
    super.dispose();
  }
}
