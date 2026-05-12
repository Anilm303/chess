class Message {
  final String id;
  final String sender;
  final String receiver;
  final String text;
  final String messageType; // 'text', 'image', 'video', 'call'
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? replyToId;
  final DateTime timestamp;
  final bool isRead;
  final String status;
  final Map<String, List<String>> reactions; // {username: [emoji, ...]}

  Message({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl,
    this.thumbnailUrl,
    this.replyToId,
    required this.timestamp,
    required this.isRead,
    this.status = 'sent',
    this.reactions = const {},
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse reactions: backend sends {username: [emoji, ...]}
    final rawReactions = json['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = <String, List<String>>{};
    rawReactions.forEach((key, value) {
      if (value is List) {
        reactions[key] = value.cast<String>();
      }
    });

    return Message(
      id: json['id'] as String,
      sender: json['sender'] as String,
      receiver: (json['receiver'] ?? json['group_id'] ?? '') as String,
      text: json['text'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      replyToId: json['reply_to_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      status:
          json['status'] as String? ??
          (json['is_read'] == true ? 'seen' : 'sent'),
      reactions: reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'receiver': receiver,
      'text': text,
      'message_type': messageType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'reply_to_id': replyToId,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'status': status,
      'reactions': reactions,
    };
  }

  Message copyWith({
    String? id,
    String? sender,
    String? receiver,
    String? text,
    String? messageType,
    String? mediaUrl,
    String? thumbnailUrl,
    String? replyToId,
    DateTime? timestamp,
    bool? isRead,
    String? status,
    Map<String, List<String>>? reactions,
  }) {
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      text: text ?? this.text,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      replyToId: replyToId ?? this.replyToId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
    );
  }

  /// Flatten all reactions into a list of emojis for display
  List<String> get allReactionEmojis {
    final emojis = <String>[];
    reactions.forEach((_, list) => emojis.addAll(list));
    return emojis;
  }
}

class ChatUser {
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String? profileImage; // Base64 string
  final String bio;
  final bool isOnline;
  final String? lastSeen;
  final String? lastMessage;
  final String? lastMessageTime;
  final int unreadCount;

  ChatUser({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profileImage,
    this.bio = '',
    this.isOnline = false,
    this.lastSeen,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      username: json['username'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileImage: json['profile_image'] as String?,
      bio: json['bio'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  String get displayName => '$firstName $lastName'.trim();

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (lastName.isNotEmpty) {
      return lastName[0].toUpperCase();
    }
    return username[0].toUpperCase();
  }
}

class GroupMember {
  final String username;
  final String displayName;
  final String? profileImage;
  final bool isOnline;

  const GroupMember({
    required this.username,
    required this.displayName,
    this.profileImage,
    required this.isOnline,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      username: json['username'] as String,
      displayName:
          json['display_name'] as String? ?? json['username'] as String,
      profileImage: json['profile_image'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }
}

class GroupChat {
  final String id;
  final String name;
  final String? avatar;
  final String createdBy;
  final List<String> admins;
  final List<GroupMember> members;
  final String? lastMessage;
  final String? lastMessageTime;
  final int unreadCount;

  const GroupChat({
    required this.id,
    required this.name,
    this.avatar,
    required this.createdBy,
    required this.admins,
    required this.members,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members_data'] as List? ?? [];
    return GroupChat(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Group',
      avatar: json['avatar'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      admins: (json['admins'] as List? ?? []).map((e) => e.toString()).toList(),
      members: rawMembers
          .whereType<Map>()
          .map(
            (member) => GroupMember.fromJson(Map<String, dynamic>.from(member)),
          )
          .toList(),
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
