class Note {
  final String id;
  final String username;
  final String displayName;
  final String? profileImage;
  final String textContent;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String mediaType; // 'text', 'image', 'video'
  final DateTime timestamp;
  final List<Map<String, dynamic>> viewers;
  final bool isOnline;

  Note({
    required this.id,
    required this.username,
    required this.displayName,
    this.profileImage,
    required this.textContent,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.timestamp,
    required this.viewers,
    required this.isOnline,
  });

  int get viewCount => viewers.length;

  factory Note.fromJson(Map<String, dynamic> json) {
    final rawViewers = json['viewers'] as List? ?? [];
    final viewers = <Map<String, dynamic>>[];
    for (final viewer in rawViewers) {
      if (viewer is Map<String, dynamic>) {
        viewers.add(viewer);
      } else if (viewer is String) {
        viewers.add({'username': viewer, 'timestamp': json['timestamp']});
      }
    }

    return Note(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImage: json['profileImage'],
      textContent: json['text_content'] ?? json['text'] ?? '',
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      mediaType: json['media_type'] ?? 'text',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      viewers: viewers,
      isOnline: json['isOnline'] ?? false,
    );
  }
}

class NoteGroup {
  final String username;
  final String displayName;
  final String? profileImage;
  final bool isOnline;
  final List<Note> notes;
  final bool hasUnviewed;

  NoteGroup({
    required this.username,
    required this.displayName,
    required this.profileImage,
    required this.isOnline,
    required this.notes,
    required this.hasUnviewed,
  });

  factory NoteGroup.fromJson(Map<String, dynamic> json) {
    final notes =
        (json['notes'] as List?)
            ?.map((n) => Note.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];

    return NoteGroup(
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImage: json['profileImage'],
      isOnline: json['isOnline'] ?? false,
      notes: notes,
      hasUnviewed: json['hasUnviewed'] ?? false,
    );
  }
}
