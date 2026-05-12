class Notification {
  final String id;
  final String username;
  final String type; // 'story_reaction', 'note_reaction'
  final String message;
  final DateTime timestamp;
  bool isRead;

  Notification({
    required this.id,
    required this.username,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      type: json['type'] ?? 'notification',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'type': type,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };
}
