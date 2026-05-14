import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import 'api_service.dart';

class MessageService extends ChangeNotifier {
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

  // For polling real-time messages
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 3);

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

  Future<bool> fetchCurrentUserProfile(String accessToken) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/messages/profile'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

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
                    newReactions[key.toString()] = list
                        .map((e) => e.toString())
                        .toList();
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
        final sender = payload['sender']?.toString() ?? message.sender;
        final receiver = payload['receiver']?.toString() ?? message.receiver;

        if (currentUsername != null && receiver != currentUsername) {
          return;
        }

        if (_selectedUserUsername == sender) {
          _currentConversation.add(message);
          await fetchConversation(sender, accessToken);
        } else {
          _upsertConversationPreview(
            username: sender,
            lastMessage: message.text,
            lastMessageTime: message.timestamp.toIso8601String(),
            unreadIncrement: 1,
          );
        }
        notifyListeners();
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
        final ids =
            (payload['message_ids'] as List?)
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
        final ids =
            (payload['message_ids'] as List?)
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
        final ids =
            (payload['message_ids'] as List?)
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
  }

  void sendTyping({
    required bool isGroupChat,
    required String targetId,
    required bool isTyping,
  }) {
    final username = _currentUserProfile?.username;
    if (username == null || _socket?.connected != true) return;
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

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

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

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

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
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/messages/groups'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

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
      print('📤 Creating group: ${requestBody['name']}');
      print('👥 Members: ${requestBody['members']}');
      print('🌐 URL: $url');
      print('🔑 Token length: ${accessToken.length}');

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

      print('📥 Response Status: ${response.statusCode}');
      print('📝 Response Body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Group created successfully');
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
          _error =
              'Server error (${response.statusCode}). Response: ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}';
        }
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Network error: $e';
      print('❌ Error creating group: $e');
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

  Future<bool> fetchConversation(String otherUser, String accessToken) async {
    try {
      final url = '${ApiService.baseUrl}/messages/conversation/$otherUser';
      _logHttp('GET $url');
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);
      _logHttpResponse('GET /messages/conversation/$otherUser', response);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentConversation = (json['messages'] as List)
              .map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList();
          final markReadUrl =
              '${ApiService.baseUrl}/messages/conversation/$otherUser/mark-read';
          _logHttp('PUT $markReadUrl');
          final markReadResponse = await http.put(
            Uri.parse(markReadUrl),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          _logHttpResponse(
            'PUT /messages/conversation/$otherUser/mark-read',
            markReadResponse,
          );
          _directTypingUser = null;
          notifyListeners();
          final index = _conversations.indexWhere(
            (item) => item.username == otherUser,
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
              unreadCount: 0,
            );
          }
          if (_selectedUserUsername != null &&
              _currentConversation.isNotEmpty) {
            final latestMessage = _currentConversation.last;
            _upsertConversationPreview(
              username: _selectedUserUsername!,
              lastMessage: latestMessage.text,
              lastMessageTime: latestMessage.timestamp.toIso8601String(),
            );
          }
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

  Future<bool> fetchGroupConversation(
    String groupId,
    String accessToken,
  ) async {
    try {
      final url = '${ApiService.baseUrl}/messages/groups/$groupId/messages';
      _logHttp('GET $url');
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);
      _logHttpResponse('GET /messages/groups/$groupId/messages', response);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _currentGroupConversation = (json['messages'] as List)
              .map((m) => Message.fromJson(m as Map<String, dynamic>))
              .toList();
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

  Future<bool> sendMessage(
    String receiver,
    String text,
    String accessToken, {
    String messageType = 'text',
    String? mediaBase64,
    String? replyToId,
    String? timestamp,
  }) async {
    if (messageType == 'text' && text.trim().isEmpty) {
      _error = 'Message cannot be empty';
      notifyListeners();
      return false;
    }

    try {
      final sentAt = timestamp ?? DateTime.now().toIso8601String();
      final url = '${ApiService.baseUrl}/messages/send';
      _logHttp('POST $url messageType=$messageType receiver=$receiver');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'receiver': receiver,
              'text': text.trim(),
              'message_type': messageType,
              'timestamp': sentAt,
              if (mediaBase64 != null) 'media_base64': mediaBase64,
              if (replyToId != null) 'reply_to_id': replyToId,
            }),
          )
          .timeout(ApiService.timeout);
      _logHttpResponse('POST /messages/send', response);

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final message = Message.fromJson(json['data']);
          _currentConversation.add(message);
          _upsertConversationPreview(
            username: receiver,
            lastMessage: message.text,
            lastMessageTime: message.timestamp.toIso8601String(),
          );
          _error = null;
          notifyListeners();
          return true;
        }
      }

      _error = 'Failed to send message';
      _logHttp(_error!);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error sending message: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
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

  Future<bool> addGroupMember(
    String groupId,
    String memberUsername,
    String accessToken,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/messages/groups/$groupId/members'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'member_username': memberUsername}),
          )
          .timeout(ApiService.timeout);
      if (response.statusCode == 200) {
        await fetchGroups(accessToken);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> removeGroupMember(
    String groupId,
    String memberUsername,
    String accessToken,
  ) async {
    try {
      final response = await http
          .delete(
            Uri.parse(
              '${ApiService.baseUrl}/messages/groups/$groupId/members/$memberUsername',
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);
      if (response.statusCode == 200) {
        await fetchGroups(accessToken);
        return true;
      }
    } catch (_) {}
    return false;
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

    try {
      final sentAt = timestamp ?? DateTime.now().toIso8601String();
      print('📤 Message $messageType upload started');
      print('📁 File: ${media.name}, Size: ${await media.length()} bytes');
      print('👤 Receiver: $receiver');
      print('🌐 URL: ${ApiService.baseUrl}/messages/send');

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
      print('✅ File read: ${mediaBytes.length} bytes');

      request.files.add(
        http.MultipartFile.fromBytes('media', mediaBytes, filename: media.name),
      );

      print('⏳ Sending $messageType to $receiver...');
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamed);
      _logHttpResponse('MULTIPART POST /messages/send', response);

      print('📥 Response Status: ${response.statusCode}');
      print(
        '📝 Response Body: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}',
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          print('✅ $messageType sent successfully!');
          final message = Message.fromJson(json['data']);
          _currentConversation.add(message);
          _upsertConversationPreview(
            username: receiver,
            lastMessage: messageType == 'video' ? '🎥 Video' : '🖼️ Image',
            lastMessageTime: message.timestamp.toIso8601String(),
          );
          _error = null;
          notifyListeners();
          return true;
        } else {
          _error = json['message'] ?? 'Failed to send $messageType';
          print('❌ Server error: $_error');
        }
      } else {
        try {
          final json = jsonDecode(response.body);
          _error =
              json['message'] ??
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
        print('❌ Send error: $_error');
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Network error: $e';
      print('❌ Exception: $e');
      notifyListeners();
      return false;
    }
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
      final response = await http
          .delete(
            Uri.parse('${ApiService.baseUrl}/messages/message/$messageId'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(ApiService.timeout);

      if (response.statusCode == 200) {}
      return false;
    } catch (e) {
      _error = 'Error deleting message: $e';
      _logHttp(_error!);
      notifyListeners();
      return false;
    }
  }

  void _startPolling(String accessToken) {
    // Cancel existing timer
    _pollTimer?.cancel();

    if (_selectedUserUsername == null) {
      return;
    }

    // Poll for new messages periodically
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_selectedUserUsername != null) {
        await fetchConversation(_selectedUserUsername!, accessToken);
      }
    });
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
