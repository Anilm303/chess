enum CallType { audio, video }

enum CallStatus {
  idle,
  ringing,
  connecting,
  connected,
  ended,
  rejected,
  failed,
}

class CallParticipant {
  final String username;
  final String displayName;
  final String? profileImage;
  final bool isLocal;
  final bool isScreenSharing;

  const CallParticipant({
    required this.username,
    required this.displayName,
    this.profileImage,
    this.isLocal = false,
    this.isScreenSharing = false,
  });

  CallParticipant copyWith({
    String? username,
    String? displayName,
    String? profileImage,
    bool? isLocal,
    bool? isScreenSharing,
  }) {
    return CallParticipant(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
      isLocal: isLocal ?? this.isLocal,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    );
  }
}

class CallInvitation {
  final String callId;
  final String roomId;
  final String callerUsername;
  final String callerDisplayName;
  final String? callerProfileImage;
  final String calleeUsername;
  final String calleeDisplayName;
  final String? calleeProfileImage;
  final CallType callType;

  const CallInvitation({
    required this.callId,
    required this.roomId,
    required this.callerUsername,
    required this.callerDisplayName,
    this.callerProfileImage,
    required this.calleeUsername,
    required this.calleeDisplayName,
    this.calleeProfileImage,
    required this.callType,
  });

  factory CallInvitation.fromJson(Map<String, dynamic> json) {
    return CallInvitation(
      callId: json['call_id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      callerUsername: json['caller_username']?.toString() ?? '',
      callerDisplayName: json['caller_display_name']?.toString() ?? '',
      callerProfileImage: json['caller_profile_image']?.toString(),
      calleeUsername: json['callee_username']?.toString() ?? '',
      calleeDisplayName: json['callee_display_name']?.toString() ?? '',
      calleeProfileImage: json['callee_profile_image']?.toString(),
      callType: (json['call_type']?.toString() ?? 'video') == 'audio'
          ? CallType.audio
          : CallType.video,
    );
  }

  bool get isVideo => callType == CallType.video;
}
