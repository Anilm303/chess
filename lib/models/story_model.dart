class Story {
  final String id;
  final String username;
  final String displayName;
  final String? profileImage;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String mediaType; // 'image' or 'video'
  final DateTime timestamp;
  final List<Map<String, dynamic>>
  viewers; // [{username: str, timestamp: str}, ...]
  final bool isOnline;
  final Map<String, String> reactions; // {username: emoji}
  final Map<String, Map<String, dynamic>>
  reactionDetails; // {username: {emoji: str, timestamp: str}}

  Story({
    required this.id,
    required this.username,
    required this.displayName,
    this.profileImage,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.mediaType,
    required this.timestamp,
    required this.viewers,
    required this.isOnline,
    this.reactions = const {},
    this.reactionDetails = const {},
  });

  bool get hasViewed => viewers.any((v) => v['username'] == username);
  bool get isExpired {
    final now = DateTime.now();
    return now.difference(timestamp).inHours >= 24;
  }

  int get viewCount => viewers.length;
  int get reactionCount => reactions.length;

  factory Story.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = <String, String>{};
    rawReactions.forEach((key, value) {
      reactions[key] = value.toString();
    });

    final rawReactionDetails =
        json['reaction_details'] as Map<String, dynamic>? ?? {};
    final reactionDetails = <String, Map<String, dynamic>>{};
    rawReactionDetails.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        reactionDetails[key] = value;
      }
    });

    final rawViewers =
        json['viewers'] as List? ?? json['viewed_by'] as List? ?? [];
    final viewers = <Map<String, dynamic>>[];
    for (final viewer in rawViewers) {
      if (viewer is Map<String, dynamic>) {
        viewers.add(viewer);
      } else if (viewer is String) {
        // Legacy format: just username string
        viewers.add({'username': viewer, 'timestamp': json['timestamp']});
      }
    }

    return Story(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImage: json['profileImage'],
      mediaUrl: json['media_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      mediaType: json['media_type'] ?? 'image',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      viewers: viewers,
      isOnline: json['isOnline'] ?? false,
      reactions: reactions,
      reactionDetails: reactionDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'profileImage': profileImage,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_type': mediaType,
      'timestamp': timestamp.toIso8601String(),
      'viewers': viewers,
      'isOnline': isOnline,
      'reactions': reactions,
      'reaction_details': reactionDetails,
    };
  }
}

class StoryGroup {
  final String username;
  final String displayName;
  final String? profileImage;
  final bool isOnline;
  final List<Story> stories;
  final bool hasUnviewed;

  StoryGroup({
    required this.username,
    required this.displayName,
    required this.profileImage,
    required this.isOnline,
    required this.stories,
    required this.hasUnviewed,
  });

  /// Total reactions across all stories in this group
  int get totalReactions {
    int count = 0;
    for (final s in stories) {
      count += s.reactions.length;
    }
    return count;
  }

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final stories =
        (json['stories'] as List?)
            ?.map((s) => Story.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return StoryGroup(
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImage: json['profileImage'],
      isOnline: json['isOnline'] ?? false,
      stories: stories,
      hasUnviewed: json['hasUnviewed'] ?? false,
    );
  }
}
