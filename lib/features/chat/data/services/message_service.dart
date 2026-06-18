import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../../../models/message_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/friend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MessageService extends ChangeNotifier {
  final FriendService? _friendService;

  MessageService({FriendService? friendService})
      : _friendService = friendService;
  List<ChatUser> _allUsers = [];
  List<ChatUser> _conversations = [];
  List<GroupChat> _groups = [];
  List<Message> _currentConversation = [];
  List<Message> _currentGroupConversation = [];
  String? _selectedUserUsername;
  String? _selectedGroupId;
  ChatUser? _currentUserProfile;
  bool _isLoading = false;
  String? _error;
  bool _isSocketConnecting = false;
  bool _isSocketConnected = false;
  String? _socketStatus;
  String? _socketToken;
  String? _directTypingUser;
  final Set<String> _groupTypingUsers = {};
  io.Socket? _socket;
  // Pending message queue (persisted)
  final List<Map<String, dynamic>> _pendingMessages = [];
  bool _processingPending = false;
  static const String _prefsPendingKey = 'pending_messages_v1';
  final _uuid = Uuid();

  // For polling real-time messages
  Timer? _pollTimer;
  // Heartbeat timer to keep last-seen updated
  Timer? _heartbeatTimer;
  // Typing throttle map
  final Map<String, DateTime> _lastTypingSent = {};
  static const Duration _typingThrottle = Duration(milliseconds: 700);

  // Getters
  List<ChatUser> get allUsers => _allUsers;
  List<ChatUser> get conversations => _conversations;
  List<GroupChat> get groups => _groups;
  List<Message> get currentConversation => _currentConversation;
  List<Message> get currentGroupConversation => _currentGroupConversation;
  String? get selectedUserUsername => _selectedUserUsername;
  String? get selectedGroupId => _selectedGroupId;
  ChatUser? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSocketConnecting => _isSocketConnecting;
  bool get isSocketConnected => _isSocketConnected;
  String? get socketStatus => _socketStatus;
  String? get typingIndicatorText {
    if (_selectedUserUsername != null && _directTypingUser != null) {
      return '$_directTypingUser is typing...';
    }
    if (_selectedGroupId != null && _groupTypingUsers.isNotEmpty) {
      final names = _groupTypingUsers.take(3).join(', ');
      return names.isEmpty ? null : '$names typing...';
    }
    return null;
  }

  int get unreadConversationCount =>
      _conversations.fold<int>(0, (sum, item) => sum + item.unreadCount) +
      _groups.fold<int>(0, (sum, item) => sum + item.unreadCount);

  void _logHttp(String message) {
    debugPrint('💬 MessageService: $message');
  }

  void _logHttpResponse(String action, http.Response response) {
    final body = response.body;
    final preview = body.length > 300 ? '${body.substring(0, 300)}...' : body;
    debugPrint(
      '💬 MessageService: $action -> ${response.statusCode} ${response.reasonPhrase ?? ''}'
          .trim(),
    );
    debugPrint('💬 MessageService: $action body: $preview');
  }

  DateTime? _parseDateTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      final aTime = _parseDateTime(a.lastMessageTime);
      final bTime = _parseDateTime(b.lastMessageTime);

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  }

  void _setSocketState({bool? connecting, bool? connected, String? status}) {
    _isSocketConnecting = connecting ?? _isSocketConnecting;
    _isSocketConnected = connected ?? _isSocketConnected;
    _socketStatus = status;
    notifyListeners();
  }

  Future<void> _refreshFriendState({bool includeRequests = true}) async {
    try {
      final friendService = _friendService;
      final socketToken = _socketToken;
      if (friendService == null || socketToken == null || socketToken.isEmpty) {
        return;
      }
      await friendService.fetchContacts(socketToken);
      if (includeRequests) {
        await friendService.fetchRequests(socketToken);
      }
    } catch (_) {}
  }

  void _updatePresence(
    String username, {
    required bool isOnline,
    String? lastSeen,
  }) {
    bool changed = false;

    _allUsers = _allUsers.map((user) {
      if (user.username != username) return user;
      changed = true;
      return ChatUser(
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        profileImage: user.profileImage,
        bio: user.bio,
        isOnline: isOnline,
        lastSeen: lastSeen ?? user.lastSeen,
        lastMessage: user.lastMessage,
        lastMessageTime: user.lastMessageTime,
        unreadCount: user.unreadCount,
      );
    }).toList();

    _conversations = _conversations.map((user) {
      if (user.username != username) return user;
      changed = true;
      return ChatUser(
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        profileImage: user.profileImage,
        bio: user.bio,
        isOnline: isOnline,
        lastSeen: lastSeen ?? user.lastSeen,
        lastMessage: user.lastMessage,
        lastMessageTime: user.lastMessageTime,
        unreadCount: user.unreadCount,
      );
    }).toList();

    _groups = _groups.map((group) {
      bool groupChanged = false;
      final updatedMembers = group.members.map((member) {
        if (member.username != username) return member;
        groupChanged = true;
        changed = true;
        return GroupMember(
          username: member.username,
          displayName: member.displayName,
          profileImage: member.profileImage,
          isOnline: isOnline,
        );
      }).toList();
      if (!groupChanged) return group;
      return GroupChat(
        id: group.id,
        name: group.name,
        avatar: group.avatar,
        createdBy: group.createdBy,
        admins: group.admins,
        members: updatedMembers,
        lastMessage: group.lastMessage,
        lastMessageTime: group.lastMessageTime,
        unreadCount: group.unreadCount,
      );
    }).toList();

    if (changed) {
      _sortConversations();
      notifyListeners();
    }
  }

  void _applyReadReceipts({
    required String senderUsername,
    required String readerUsername,
    required List<String> messageIds,
  }) {
    final currentUser = _currentUserProfile?.username;
    if (currentUser == null || currentUser != senderUsername) {
      return;
    }
    if (_selectedUserUsername != readerUsername) {
      return;
    }

    final idSet = messageIds.toSet();
    bool changed = false;
    _currentConversation = _currentConversation.map((message) {
      if (message.sender != senderUsername ||
          message.receiver != readerUsername ||
          !idSet.contains(message.id) ||
          message.isRead) {
        return message;
      }
      changed = true;
      return message.copyWith(isRead: true);
    }).toList();

    if (changed) {
      final index = _conversations.indexWhere(
        (item) => item.username == readerUsername,
      );
      if (index != -1) {
        final existing = _conversations[index];
        _conversations[index] = ChatUser(
          username: existing.username,
          firstName: existing.firstName,
          lastName: existing.lastName,
          email: existing.email,
          profileImage: existing.profileImage,
          bio: existing.bio,
          isOnline: existing.isOnline,
          lastSeen: existing.lastSeen,
          lastMessage: existing.lastMessage,
          lastMessageTime: existing.lastMessageTime,
          unreadCount: existing.unreadCount,
        );
      }
      notifyListeners();
    }
  }

  void _applyMessageStatusUpdate({
    required List<String> messageIds,
    required String conversationWith,
    required String status,
    required bool isRead,
  }) {
    final idSet = messageIds.toSet();
    bool changed = false;

    _currentConversation = _currentConversation.map((message) {
      if (!idSet.contains(message.id) ||
          message.receiver != conversationWith &&
              message.sender != conversationWith) {
        return message;
      }
      if (message.status == status && message.isRead == isRead) {
        return message;
      }
      changed = true;
      return message.copyWith(status: status, isRead: isRead);
    }).toList();

    _currentGroupConversation = _currentGroupConversation.map((message) {
      if (!idSet.contains(message.id)) return message;
      if (message.status == status && message.isRead == isRead) return message;
      changed = true;
      return message.copyWith(status: status, isRead: isRead);
    }).toList();

    if (changed) {
      notifyListeners();
    }
  }

  void _setDirectTyping(String sender, bool isTyping) {
    if (_selectedUserUsername != sender) return;
    final nextValue = isTyping ? sender : null;
    if (_directTypingUser == nextValue) return;
    _directTypingUser = nextValue;
    notifyListeners();
  }

  void _setGroupTyping(String username, String groupId, bool isTyping) {
    if (_selectedGroupId != groupId) return;
    final changed = isTyping
        ? _groupTypingUsers.add(username)
        : _groupTypingUsers.remove(username);
    if (changed) {
      notifyListeners();
    }
  }

  void _upsertConversationPreview({
    required String username,
    String? lastMessage,
    String? lastMessageTime,
    int unreadIncrement = 0,
  }) {
    final index = _conversations.indexWhere(
      (user) => user.username == username,
    );
    if (index != -1) {
      final existing = _conversations[index];
      _conversations[index] = ChatUser(
        username: existing.username,
        firstName: existing.firstName,
        lastName: existing.lastName,
        email: existing.email,
        profileImage: existing.profileImage,
        bio: existing.bio,
        isOnline: existing.isOnline,
        lastSeen: existing.lastSeen,
        lastMessage: lastMessage ?? existing.lastMessage,
        lastMessageTime: lastMessageTime ?? existing.lastMessageTime,
        unreadCount: existing.unreadCount + unreadIncrement,
      );
      _sortConversations();
      return;
    }

    final matchingUser = _allUsers.where((user) => user.username == username);
    if (matchingUser.isNotEmpty) {
      final user = matchingUser.first;
      _conversations.insert(
        0,
        ChatUser(
          username: user.username,
          firstName: user.firstName,
          lastName: user.lastName,
          email: user.email,
          profileImage: user.profileImage,
          bio: user.bio,
          isOnline: user.isOnline,
          lastSeen: user.lastSeen,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          unreadCount: user.unreadCount + unreadIncrement,
        ),
      );
      _sortConversations();
    }
  }

  String _previewTextForMessage(String messageType, String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    switch (messageType) {
      case 'image':
        return '🖼️ Image';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Voice note';
      case 'call':
        return '📞 Call';
      default:
        return '';
    }
  }

  Future<bool> fetchCurrentUserProfile(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/messages/profile'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentUserProfile = ChatUser.fromJson(json['user']);
          connectSocket(accessToken);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Error fetching profile: $e';
      notifyListeners();
      return false;
    }
  }

  void connectSocket(String accessToken, {bool forceReconnect = false}) {
    if (_socket?.connected == true &&
        _socketToken == accessToken &&
        !forceReconnect) {
      return;
    }
    _socketToken = accessToken;
    _socket?.offAny();
    _socket?.disconnect();
    _socket?.dispose();
    final socketBaseUrl = ApiService.socketBaseUrl;
    _logHttp(
      'Connecting socket to $socketBaseUrl (forceReconnect=$forceReconnect)',
    );
    _setSocketState(
      connecting: true,
      connected: false,
      status: 'Connecting...',
    );
    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setQuery({'token': accessToken})
          .build(),
    );
    _socket!
      ..onConnect((_) {
        _logHttp('Socket connected (id=${_socket?.id})');
        _setSocketState(
          connecting: false,
          connected: true,
          status: 'Connected',
        );
        _refreshFriendState();
        // Load any persisted pending messages and attempt flush
        _loadPendingMessages().then((_) => _processPendingQueue(accessToken));
        // Start heartbeat to server every 30 seconds
        try {
          _heartbeatTimer?.cancel();
          _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
            final username = _currentUserProfile?.username;
            if (username != null && _socket?.connected == true) {
              _socket?.emit('heartbeat', {'username': username});
            }
          });
        } catch (_) {}
      })
      ..onDisconnect((_) {
        _logHttp('Socket disconnected');
        _setSocketState(
          connecting: false,
          connected: false,
          status: 'Disconnected',
        );
      })
      ..onConnectError((error) {
        _setSocketState(
          connecting: false,
          connected: false,
          status: 'Connection failed',
        );
        _logHttp('Socket connect error: $error');
      })
      ..onError((error) {
        _setSocketState(
          connecting: false,
          connected: false,
          status: 'Socket error',
        );
        _logHttp('Socket error: $error');
      })
      ..onReconnectAttempt((_) {
        _logHttp('Socket reconnect attempt');
        _setSocketState(
          connecting: true,
          connected: false,
          status: 'Reconnecting...',
        );
      })
      ..onReconnect((_) {
        _logHttp('Socket reconnected');
        _setSocketState(
          connecting: false,
          connected: true,
          status: 'Connected',
        );
      })
      ..onReconnectFailed((_) {
        _logHttp('Socket reconnect failed');
        _setSocketState(
          connecting: false,
          connected: false,
          status: 'Reconnection failed',
        );
      })
      ..on('user_online', (data) {
        _logHttp('Socket event user_online: $data');
        if (data is Map) {
          final username = data['username']?.toString();
          if (username != null && username.isNotEmpty) {
            _updatePresence(username, isOnline: true);
          }
        }
      })
      ..on('user_offline', (data) {
        _logHttp('Socket event user_offline: $data');
        if (data is Map) {
          final username = data['username']?.toString();
          if (username != null && username.isNotEmpty) {
            _updatePresence(username, isOnline: false);
          }
        }
      })
      ..on('message_deleted', (data) {
        _logHttp('Socket event message_deleted: $data');
        if (data is Map) {
          final messageId = data['message_id']?.toString();
          final conversationWith = data['conversation_with']?.toString();
          if (messageId != null && _selectedUserUsername == conversationWith) {
            final index = _currentConversation.indexWhere(
              (m) => m.id == messageId,
            );
            if (index != -1) {
              final oldMsg = _currentConversation[index];
              _currentConversation[index] = oldMsg.copyWith(
                text: 'This message was unsent',
                messageType: 'deleted',
              );
              notifyListeners();
            }
          }
        }
      })
      ..on('message_reaction', (data) {
        _logHttp('Socket event message_reaction: $data');
        if (data is Map) {
          final messageId = data['message_id']?.toString();
          final conversationWith = data['conversation_with']?.toString();
          if (messageId != null && _selectedUserUsername == conversationWith) {
            final index = _currentConversation.indexWhere(
              (m) => m.id == messageId,
            );
            if (index != -1) {
              final oldMsg = _currentConversation[index];
              final updatedReactionsRaw = data['reactions'] as Map?;
              if (updatedReactionsRaw != null) {
                final Map<String, List<String>> newReactions = {};
                for (var key in updatedReactionsRaw.keys) {
                  final list = updatedReactionsRaw[key];
                  if (list is List) {
                    newReactions[key.toString()] =
                        list.map((e) => e.toString()).toList();
                  }
                }
                _currentConversation[index] = oldMsg.copyWith(
                  reactions: newReactions,
                );
                notifyListeners();
              }
            }
          }
        }
      })
      ..on('message_received', (data) async {
        _logHttp('Socket event message_received: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final message = Message.fromJson(payload);
        final currentUsername = _currentUserProfile?.username;
        final sender = message.sender;
        final receiver = message.receiver;

        if (currentUsername != null && receiver != currentUsername) {
          return;
        }

        if (_selectedUserUsername == sender) {
          // Optimized: Add to local conversation immediately
          bool alreadyExists = _currentConversation.any((m) => m.id == message.id);
          if (!alreadyExists) {
            _currentConversation.add(message);
            notifyListeners();
          }
          // Mark as read in background
          final token = _socketToken;
          if (token != null) {
            http.put(
              Uri.parse('${ApiService.baseUrl}/messages/conversation/$sender/mark-read'),
              headers: {'Authorization': 'Bearer $token'},
            );
          }
        } else {
          _upsertConversationPreview(
            username: sender,
            lastMessage: _previewTextForMessage(message.messageType, message.text),
            lastMessageTime: message.timestamp.toIso8601String(),
            unreadIncrement: 1,
          );
        }
        notifyListeners();
        // Acknowledge receipt to server
        try {
          if (currentUsername != null) {
            _socket?.emit('message_ack', {
              'username': currentUsername,
              'message_ids': [message.id],
            });
          }
        } catch (_) {}
      })
      ..on('group_message_received', (data) async {
        _logHttp('Socket event group_message_received: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final groupId = payload['group_id']?.toString();
        if (groupId == null || groupId.isEmpty) return;

        if (_selectedGroupId == groupId) {
          await fetchGroupConversation(groupId, accessToken);
        } else {
          await fetchGroups(accessToken);
        }
        notifyListeners();
      })
      ..on('user_typing', (data) {
        _logHttp('Socket event user_typing: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final sender = payload['sender']?.toString();
        final isTyping = payload['is_typing'] != false;
        if (sender != null && sender.isNotEmpty) {
          _setDirectTyping(sender, isTyping);
        }
      })
      ..on('friend_request', (data) {
        _logHttp('Socket event friend_request: $data');
        try {
          _refreshFriendState(includeRequests: true);
        } catch (_) {}
      })
      ..on('friend_request_responded', (data) {
        _logHttp('Socket event friend_request_responded: $data');
        try {
          _refreshFriendState(includeRequests: true);
        } catch (_) {}
      })
      ..on('friend_added', (data) {
        _logHttp('Socket event friend_added: $data');
        try {
          _refreshFriendState(includeRequests: true);
        } catch (_) {}
      })
      ..on('friend_list_update', (data) {
        _logHttp('Socket event friend_list_update: $data');
        try {
          _refreshFriendState(includeRequests: true);
        } catch (_) {}
      })
      ..on('group_user_typing', (data) {
        _logHttp('Socket event group_user_typing: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final username = payload['username']?.toString();
        final groupId = payload['group_id']?.toString();
        final isTyping = payload['is_typing'] != false;
        if (username != null &&
            username.isNotEmpty &&
            groupId != null &&
            groupId.isNotEmpty) {
          _setGroupTyping(username, groupId, isTyping);
        }
      })
      ..on('message_read', (data) {
        _logHttp('Socket event message_read: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final senderUsername = payload['sender_username']?.toString() ?? '';
        final readerUsername = payload['reader_username']?.toString() ?? '';
        final ids = (payload['message_ids'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [];
        if (senderUsername.isNotEmpty &&
            readerUsername.isNotEmpty &&
            ids.isNotEmpty) {
          _applyReadReceipts(
            senderUsername: senderUsername,
            readerUsername: readerUsername,
            messageIds: ids,
          );
        }
      })
      ..on('message_delivered', (data) {
        _logHttp('Socket event message_delivered: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final conversationWith = payload['conversation_with']?.toString() ?? '';
        final ids = (payload['message_ids'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [];
        if (conversationWith.isNotEmpty && ids.isNotEmpty) {
          _applyMessageStatusUpdate(
            messageIds: ids,
            conversationWith: conversationWith,
            status: 'delivered',
            isRead: false,
          );
        }
      })
      ..on('message_seen', (data) {
        _logHttp('Socket event message_seen: $data');
        if (data is! Map) return;
        final payload = Map<String, dynamic>.from(data);
        final conversationWith = payload['conversation_with']?.toString() ?? '';
        final ids = (payload['message_ids'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [];
        if (conversationWith.isNotEmpty && ids.isNotEmpty) {
          _applyMessageStatusUpdate(
            messageIds: ids,
            conversationWith: conversationWith,
            status: 'seen',
            isRead: true,
          );
        }
      });
    _socket!.connect();
  }

  void disconnectSocket({bool notify = true}) {
    _socketToken = null;
    _directTypingUser = null;
    _groupTypingUsers.clear();
    _isSocketConnecting = false;
    _isSocketConnected = false;
    _socketStatus = 'Disconnected';
    if (notify) {
      notifyListeners();
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void sendTyping({
    required bool isGroupChat,
    required String targetId,
    required bool isTyping,
  }) {
    final username = _currentUserProfile?.username;
    if (username == null || _socket?.connected != true) return;
    final now = DateTime.now();
    final key = isGroupChat ? 'group:$targetId' : 'user:$targetId';
    final last = _lastTypingSent[key];
    if (last != null && now.difference(last) < _typingThrottle) return;
    _lastTypingSent[key] = now;
    if (isGroupChat) {
      _socket?.emit('group_typing', {
        'group_id': targetId,
        'username': username,
        'is_typing': isTyping,
      });
      return;
    }
    _socket?.emit('typing', {
      'receiver': targetId,
      'sender': username,
      'is_typing': isTyping,
    });
  }

  Future<bool> fetchAllUsers(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = '${ApiService.baseUrl}/messages/users';
      _logHttp('GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);

      _logHttpResponse('GET /messages/users', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final List usersData = json['users'] as List;
          _logHttp('Fetched ${usersData.length} users');

          _allUsers = usersData
              .map((u) => ChatUser.fromJson(u as Map<String, dynamic>))
              .toList();

          // Sort by online status (online first) then by name
          _allUsers.sort((a, b) {
            if (a.isOnline != b.isOnline) {
              return a.isOnline ? -1 : 1;
            }
            return a.displayName.compareTo(b.displayName);
          });
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = json['message'] ?? 'Failed to fetch users';
          _logHttp('Server error: $_error');
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
        _logHttp('HTTP error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _error =
          'Connection failed. Please check if backend is running at ${ApiService.baseUrl}';
      _logHttp('Network error in fetchAllUsers: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> fetchConversations(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = '${ApiService.baseUrl}/messages/conversations';
      _logHttp('GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);

      _logHttpResponse('GET /messages/conversations', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final List convData = json['conversations'] as List;
          _logHttp('Fetched ${convData.length} conversations');

          _conversations = convData
              .map((c) => ChatUser.fromJson(c as Map<String, dynamic>))
              .toList();

          // Sort by last message time (newest first)
          _conversations.sort((a, b) {
            if (a.lastMessageTime == null || b.lastMessageTime == null) {
              return (b.lastMessageTime ?? '').compareTo(
                a.lastMessageTime ?? '',
              );
            }
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          });

          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = json['message'] ?? 'Failed to fetch conversations';
          _logHttp('Server error: $_error');
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
        _logHttp('HTTP error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _error = 'Connection failed: $e';
      _logHttp('Network error in fetchConversations: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> fetchGroups(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/messages/groups'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _groups = (json['groups'] as List)
              .map((item) => GroupChat.fromJson(item as Map<String, dynamic>))
              .toList();
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Failed to load groups: $e';
      notifyListeners();
      return false;
    }
  }

  /// Debug helper: populate a few sample conversations locally for UI testing.
  void debugPopulateSampleConversations() {
    _conversations = [
      ChatUser(
        username: 'alice',
        firstName: 'Alice',
        lastName: 'K',
        email: 'alice@example.com',
        profileImage: null,
        isOnline: true,
        lastMessage: 'Hi there!',
        lastMessageTime: DateTime.now().toIso8601String(),
        unreadCount: 1,
      ),
      ChatUser(
        username: 'bob',
        firstName: 'Bob',
        lastName: 'S',
        email: 'bob@example.com',
        profileImage: null,
        isOnline: false,
        lastMessage: 'Let\'s play later',
        lastMessageTime:
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        unreadCount: 0,
      ),
    ];
    notifyListeners();
  }

  /// Debug helper: populate a few sample users for UI testing.
  void debugPopulateSampleUsers() {
    _allUsers = [
      ChatUser(
        username: 'alice',
        firstName: 'Alice',
        lastName: 'K',
        email: 'alice@example.com',
        profileImage: null,
        isOnline: true,
        lastMessage: 'Hi there!',
        lastMessageTime: DateTime.now().toIso8601String(),
        unreadCount: 1,
      ),
      ChatUser(
        username: 'bob',
        firstName: 'Bob',
        lastName: 'S',
        email: 'bob@example.com',
        profileImage: null,
        isOnline: false,
        lastMessage: 'Let\'s play later',
        lastMessageTime:
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        unreadCount: 0,
      ),
      ChatUser(
        username: 'charlie',
        firstName: 'Charlie',
        lastName: 'P',
        email: 'charlie@example.com',
        profileImage: null,
        isOnline: false,
        lastMessage: null,
        lastMessageTime: null,
        unreadCount: 0,
      ),
    ];
    notifyListeners();
  }

  Future<bool> createGroup({
    required String name,
    required List<String> members,
    String? avatarBase64,
    required String accessToken,
  }) async {
    try {
      _error = null;

      final groupName = name.trim();
      if (groupName.isEmpty) {
        _error = 'Group name cannot be empty';
        notifyListeners();
        return false;
      }

      if (members.isEmpty) {
        _error = 'Select at least 1 member';
        notifyListeners();
        return false;
      }

      final requestBody = {
        'name': groupName,
        'members': members,
        if (avatarBase64 != null && avatarBase64.isNotEmpty)
          'avatar': avatarBase64,
      };

      final url = '${ApiService.baseUrl}/messages/groups';
      debugPrint('📤 Creating group: ${requestBody['name']}');
      debugPrint('👥 Members: ${requestBody['members']}');
      debugPrint('🌐 URL: $url');
      debugPrint('🔑 Token length: ${accessToken.length}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(ApiService.timeout);

      debugPrint('📥 Response Status: ${response.statusCode}');
      debugPrint('📝 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        debugPrint('✅ Group created successfully');
        _error = null;
        await fetchGroups(accessToken);
        notifyListeners();
        return true;
      }

      // Better error parsing
      try {
        final json = jsonDecode(response.body);
        _error = json['message']?.toString() ?? 'Failed to create group';
      } catch (_) {
        if (response.statusCode == 404) {
          _error = 'Backend endpoint not found. Ensure backend is updated.';
        } else if (response.statusCode == 401) {
          _error = 'Authentication failed. Please login again.';
        } else {
          final shortenedBody = response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body;
          _error =
              'Server error (${response.statusCode}). Response: $shortenedBody';
        }
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('❌ Error creating group: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String bio,
    String? profileImage,
    required String accessToken,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiService.baseUrl}/messages/profile/update'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'first_name': firstName,
              'last_name': lastName,
              'bio': bio,
              'profile_image': profileImage,
            }),
          )
          .timeout(ApiService.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentUserProfile = ChatUser.fromJson(json['user']);
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to update profile';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error updating profile: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> selectUser(String username, String accessToken) async {
    _selectedUserUsername = username;
    _selectedGroupId = null;
    _directTypingUser = null;
    _groupTypingUsers.clear();
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Fetch initial conversation
    final success = await fetchConversation(username, accessToken);

    // Stop polling if there was any
    stopPolling();

    _isLoading = false;
    notifyListeners();

    return success;
  }

  Future<bool> selectGroup(String groupId, String accessToken) async {
    _selectedGroupId = groupId;
    _selectedUserUsername = null;
    _directTypingUser = null;
    _groupTypingUsers.clear();
    _isLoading = true;
    _error = null;
    notifyListeners();

    final success = await fetchGroupConversation(groupId, accessToken);
    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> fetchConversation(
    String otherUser,
    String accessToken, {
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
    try {
      final url =
          '${ApiService.baseUrl}/messages/conversation/$otherUser?limit=$limit&offset=$offset';
      _logHttp('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);
      _logHttpResponse('GET /messages/conversation/$otherUser', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final List<Message> newMessages = (json['messages'] as List)
              .map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList();

          if (append) {
            // Prepend new (older) messages
            _currentConversation.insertAll(0, newMessages);
          } else {
            _currentConversation = newMessages;
          }

          debugPrint(
            '💬 fetchConversation: loaded ${newMessages.length} messages (append=$append)',
          );

          if (!append) {
            // Mark as read only on initial load
            final markReadUrl =
                '${ApiService.baseUrl}/messages/conversation/$otherUser/mark-read';
            http.put(
              Uri.parse(markReadUrl),
              headers: {'Authorization': 'Bearer $accessToken'},
            );
          }
          _directTypingUser = null;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Error fetching conversation: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMoreMessages(String accessToken) async {
    if (_selectedUserUsername == null || _isLoading) return;
    final offset = _currentConversation.length;
    await fetchConversation(
      _selectedUserUsername!,
      accessToken,
      offset: offset,
      append: true,
    );
  }

  Future<bool> fetchGroupConversation(
    String groupId,
    String accessToken, {
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
    try {
      final url =
          '${ApiService.baseUrl}/messages/groups/$groupId/messages?limit=$limit&offset=$offset';
      _logHttp('GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);
      _logHttpResponse('GET /messages/groups/$groupId/messages', response);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final List<Message> newMessages = (json['messages'] as List)
              .map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList();

          if (append) {
            _currentGroupConversation.insertAll(0, newMessages);
          } else {
            _currentGroupConversation = newMessages;
          }
          await fetchGroups(accessToken);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Error fetching group conversation: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMoreGroupMessages(String accessToken) async {
    if (_selectedGroupId == null || _isLoading) return;
    final offset = _currentGroupConversation.length;
    await fetchGroupConversation(
      _selectedGroupId!,
      accessToken,
      offset: offset,
      append: true,
    );
  }

  Future<bool> sendMessage(
    String receiver,
    String text,
    String accessToken, {
    String messageType = 'text',
    String? mediaBase64,
    String? mediaPath,
    String? replyToId,
    String? timestamp,
  }) async {
    if (messageType == 'text' && text.trim().isEmpty) {
      _error = 'Message cannot be empty';
      notifyListeners();
      return false;
    }

    final allowed = await _canInteractWithUser(receiver, accessToken);
    if (!allowed) {
      _error = 'Message and call are available only after becoming friends';
      notifyListeners();
      return false;
    }

    // Enqueue message for reliable delivery (persisted). A background
    // worker will attempt to POST to REST endpoint and remove on success.
    final localId = 'local_${_uuid.v4()}';
    final sentAt = timestamp ?? DateTime.now().toIso8601String();

    final pending = {
      'local_id': localId,
      'receiver': receiver,
      'text': text.trim(),
      'message_type': messageType,
      'media_base64': mediaBase64,
      'media_path': mediaPath,
      'reply_to_id': replyToId,
      'timestamp': sentAt,
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add to local conversation immediately for optimistic UI
    final optimistic = Message(
      id: localId,
      sender: _currentUserProfile?.username ?? 'me',
      receiver: receiver,
      text: text.trim(),
      messageType: messageType,
      mediaUrl: mediaPath,
      timestamp: DateTime.parse(sentAt),
      status: 'sending',
      isRead: false, // Added required parameter
    );
    _currentConversation.add(optimistic);
    _upsertConversationPreview(
      username: receiver,
      lastMessage: _previewTextForMessage(messageType, optimistic.text),
      lastMessageTime: optimistic.timestamp.toIso8601String(),
    );
    notifyListeners();

    _pendingMessages.add(pending);
    await _savePendingMessages();
    _processPendingQueue(accessToken);
    return true;
  }

  Future<void> _loadPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsPendingKey);
      if (raw == null || raw.isEmpty) return;
      final List decoded = jsonDecode(raw) as List;
      _pendingMessages.clear();
      for (final item in decoded) {
        if (item is Map) {
          _pendingMessages.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      _logHttp('Failed loading pending messages: $e');
    }
  }

  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsPendingKey, jsonEncode(_pendingMessages));
    } catch (e) {
      _logHttp('Failed saving pending messages: $e');
    }
  }

  Future<void> _processPendingQueue(String accessToken) async {
    if (_processingPending) return;
    if (_pendingMessages.isEmpty) return;
    _processingPending = true;
    try {
      for (int i = 0; i < _pendingMessages.length;) {
        final item = _pendingMessages[i];
        try {
          final url = '${ApiService.baseUrl}/messages/send';
          _logHttp(
            'Flushing pending -> POST $url receiver=${item['receiver']}',
          );
          final bodyMap = {
            'receiver': item['receiver'],
            'text': item['text'],
            'message_type': item['message_type'],
            'timestamp': item['timestamp'],
            if (item['media_base64'] != null)
              'media_base64': item['media_base64'],
            if (item['media_path'] != null) 'media_path': item['media_path'],
            if (item['reply_to_id'] != null) 'reply_to_id': item['reply_to_id'],
          };

          final response = await http
              .post(
                Uri.parse(url),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(bodyMap),
              )
              .timeout(ApiService.timeout);

          _logHttpResponse('POST /messages/send (pending)', response);
          if (response.statusCode == 201) {
            final json = jsonDecode(response.body);
            if (json['success'] == true) {
              final serverMsg = Message.fromJson(json['data']);
              // Replace optimistic message in conversation (match by local_id)
              final localId = item['local_id']?.toString() ?? '';
              final idx = _currentConversation.indexWhere(
                (m) => m.id == localId,
              );
              if (idx != -1) {
                _currentConversation[idx] = serverMsg;
              } else {
                _currentConversation.add(serverMsg);
              }
              _pendingMessages.removeAt(i);
              await _savePendingMessages();
              _upsertConversationPreview(
                username: serverMsg.receiver,
                lastMessage: _previewTextForMessage(
                  serverMsg.messageType,
                  serverMsg.text,
                ),
                lastMessageTime: serverMsg.timestamp.toIso8601String(),
              );
              notifyListeners();
              // continue with same index (next item shifted into i)
              continue;
            }
          }

          // Non-success path: increment retries and backoff
          item['retries'] = (item['retries'] as int? ?? 0) + 1;
          if ((item['retries'] as int) > 5) {
            // Give up after 5 retries; mark message as failed locally
            final localId = item['local_id']?.toString() ?? '';
            final idx = _currentConversation.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              _currentConversation[idx] = _currentConversation[idx].copyWith(
                status: 'failed',
              );
            }
            _pendingMessages.removeAt(i);
            await _savePendingMessages();
            notifyListeners();
            continue;
          }

          // Wait exponential backoff then try next pending
          final waitMs = 500 * (1 << ((item['retries'] as int) - 1));
          await Future.delayed(Duration(milliseconds: waitMs));
          i += 1;
        } catch (e) {
          _logHttp('Error flushing pending message: $e');
          // network error — increment retries and break to retry later
          item['retries'] = (item['retries'] as int? ?? 0) + 1;
          await _savePendingMessages();
          break;
        }
      }
    } finally {
      _processingPending = false;
    }
  }

  Future<bool> sendGroupMessage(
    String groupId,
    String text,
    String accessToken, {
    String messageType = 'text',
    String? timestamp,
  }) async {
    if (messageType == 'text' && text.trim().isEmpty) {
      return false;
    }
    try {
      final sentAt = timestamp ?? DateTime.now().toIso8601String();
      final url = '${ApiService.baseUrl}/messages/groups/$groupId/messages';
      _logHttp('POST $url groupMessageType=$messageType groupId=$groupId');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': text,
              'message_type': messageType,
              'timestamp': sentAt,
            }),
          )
          .timeout(ApiService.timeout);
      _logHttpResponse('POST /messages/groups/$groupId/messages', response);
      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentGroupConversation.add(
            Message.fromJson(json['data'] as Map<String, dynamic>),
          );
          await fetchGroups(accessToken);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'Error sending group message: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendGroupMessageFile(
    String groupId,
    XFile media,
    String accessToken, {
    String messageType = 'video',
    String? text,
    String? timestamp,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final sentAt = timestamp ?? DateTime.now().toIso8601String();
      final url = '${ApiService.baseUrl}/messages/groups/$groupId/messages';
      _logHttp(
        'MULTIPART POST $url groupId=$groupId messageType=$messageType file=${media.name}',
      );
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['message_type'] = messageType;
      request.fields['text'] = text?.trim() ?? '';
      request.fields['timestamp'] = sentAt;

      final mediaBytes = await media.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('media', mediaBytes, filename: media.name),
      );

      final streamed = await request.send().timeout(ApiService.timeout);
      final response = await http.Response.fromStream(streamed);
      _logHttpResponse(
        'MULTIPART POST /messages/groups/$groupId/messages',
        response,
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentGroupConversation.add(
            Message.fromJson(json['data'] as Map<String, dynamic>),
          );
          await fetchGroups(accessToken);
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to send group $messageType';
      _logHttp(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error sending group $messageType: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGroupAdmin(
    String groupId,
    String memberUsername,
    bool isAdmin,
    String accessToken,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiService.baseUrl}/messages/groups/$groupId/admins'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'member_username': memberUsername,
              'is_admin': isAdmin,
            }),
          )
          .timeout(ApiService.timeout);
      if (response.statusCode == 200) {
        await fetchGroups(accessToken);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> sendMessageFile(
    String receiver,
    XFile media,
    String accessToken, {
    String messageType = 'video',
    String? text,
    String? replyToId,
    String? timestamp,
  }) async {
    _error = null;
    notifyListeners();

    final allowed = await _canInteractWithUser(receiver, accessToken);
    if (!allowed) {
      _error = 'Message and call are available only after becoming friends';
      notifyListeners();
      return false;
    }

    try {
      final sentAt = timestamp ?? DateTime.now().toIso8601String();
      debugPrint('📤 Message $messageType upload started');
      debugPrint('📁 File: ${media.name}, Size: ${await media.length()} bytes');
      debugPrint('👤 Receiver: $receiver');
      debugPrint('🌐 URL: ${ApiService.baseUrl}/messages/send');

      final url = '${ApiService.baseUrl}/messages/send';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['receiver'] = receiver;
      request.fields['message_type'] = messageType;
      request.fields['text'] = text?.trim() ?? '';
      request.fields['timestamp'] = sentAt;
      if (replyToId != null) {
        request.fields['reply_to_id'] = replyToId;
      }

      final mediaBytes = await media.readAsBytes();
      debugPrint('✅ File read: ${mediaBytes.length} bytes');

      request.files.add(
        http.MultipartFile.fromBytes('media', mediaBytes, filename: media.name),
      );

      debugPrint('⏳ Sending $messageType to $receiver...');
      final streamed = await request.send().timeout(
            const Duration(seconds: 120),
          );
      final response = await http.Response.fromStream(streamed);
      _logHttpResponse('MULTIPART POST /messages/send', response);

      debugPrint('📥 Response Status: ${response.statusCode}');
      final shortBody = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
      debugPrint('📝 Response Body: $shortBody');

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          debugPrint('✅ $messageType sent successfully!');
          final message = Message.fromJson(json['data']);
          _currentConversation.add(message);
          _upsertConversationPreview(
            username: receiver,
            lastMessage: _previewTextForMessage(messageType, text ?? ''),
            lastMessageTime: message.timestamp.toIso8601String(),
          );
          _error = null;
          notifyListeners();
          return true;
        } else {
          _error = json['message'] ?? 'Failed to send $messageType';
          debugPrint('❌ Server error: $_error');
        }
      } else {
        try {
          final json = jsonDecode(response.body);
          _error = json['message'] ??
              'Failed to send $messageType (${response.statusCode})';
        } catch (_) {
          if (response.statusCode == 413) {
            _error = 'File too large';
          } else if (response.statusCode == 401) {
            _error = 'Authentication failed. Please login again';
          } else {
            _error = 'Server error (${response.statusCode})';
          }
        }
        debugPrint('❌ Send error: $_error');
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('❌ Exception: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> _canInteractWithUser(String username, String accessToken) async {
    final friendService = _friendService;
    if (friendService == null) {
      return true;
    }
    if (friendService.isFriend(username)) {
      return true;
    }

    // Refresh contacts once to avoid false negatives from stale state.
    await friendService.fetchContacts(accessToken);
    return friendService.isFriend(username);
  }

  /// Toggle an emoji reaction on a message via the API
  Future<bool> reactToMessage(
    String messageId,
    String emoji,
    String accessToken,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/messages/react/$messageId'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'emoji': emoji}),
          )
          .timeout(ApiService.timeout);

      if (response.statusCode == 200) {
        // Refresh conversation to get updated reactions
        if (_selectedUserUsername != null) {
          await fetchConversation(_selectedUserUsername!, accessToken);
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error reacting to message: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  /// Delete a message for everyone
  Future<bool> deleteMessage(String messageId, String accessToken) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/messages/message/$messageId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(ApiService.timeout);

      if (response.statusCode == 200) {}
      return false;
    } catch (e) {
      _error = 'Error deleting message: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void deselectUser() {
    _selectedUserUsername = null;
    _selectedGroupId = null;
    _currentConversation = [];
    _currentGroupConversation = [];
    _directTypingUser = null;
    _groupTypingUsers.clear();
    stopPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    disconnectSocket(notify: false);
    super.dispose();
  }
}
