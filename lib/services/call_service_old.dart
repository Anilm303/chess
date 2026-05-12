import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/call_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';

class CallService extends ChangeNotifier {
  IO.Socket? _socket;
  String? _accessToken;
  String? _currentUsername;
  String? _currentDisplayName;
  String? _callId;
  String? _roomId;
  String? _currentProfileImage;
  String? _callPartnerUsername;

  CallType _callType = CallType.video;
  CallStatus _status = CallStatus.idle;
  bool _audioEnabled = true;
  bool _videoEnabled = true;
  bool _speakerOn = true;
  bool _renderersReady = false;
  bool _isOutgoing = false;

  CallInvitation? _incomingCall;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final List<CallParticipant> _participants = [];
  String? _error;

  IO.Socket? get socket => _socket;
  String? get currentUsername => _currentUsername;
  String? get currentDisplayName => _currentDisplayName;
  CallStatus get status => _status;
  CallType get callType => _callType;
  bool get isVideoCall => _callType == CallType.video;
  bool get audioEnabled => _audioEnabled;
  bool get videoEnabled => _videoEnabled;
  bool get speakerOn => _speakerOn;
  bool get isConnected => _status == CallStatus.connected;
  String? get error => _error;
  CallInvitation? get incomingCall => _incomingCall;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer get localRenderer => _localRenderer;
  Iterable<MapEntry<String, RTCVideoRenderer>> get remoteRendererEntries =>
      _remoteRenderers.entries;

  Future<void> connect({
    required String accessToken,
    required String username,
    required String displayName,
  }) async {
    _accessToken = accessToken;
    _currentUsername = username;
    _currentDisplayName = displayName;

    if (_socket?.connected == true) return;

    if (!_renderersReady) {
      await _localRenderer.initialize();
      _renderersReady = true;
    }

    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setQuery({'token': accessToken})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        try {
          print('Socket connected (id=${_socket!.id}) to $baseUrl');
        } catch (_) {
          print('Socket connected');
        }
      })
      ..onConnectError((err) => print('Socket connect error: $err'))
      ..onConnectTimeout((_) => print('Socket connect timeout'))
      ..onDisconnect((_) {
        print('Socket disconnected');
        _status = CallStatus.ended;
        notifyListeners();
      })
      ..on('incoming_call', (data) {
        print('📞 Incoming call event received: $data');
        try {
          _incomingCall = CallInvitation.fromJson(
            Map<String, dynamic>.from(data),
          );
          _status = CallStatus.ringing;
          _error = null;
          print(
            '🔔 Call status updated to RINGING for ${_incomingCall?.callerUsername}',
          );
          notifyListeners();
        } catch (e) {
          print('❌ Error handling incoming_call: $e');
        }
      })
      ..on('call_accepted', (data) {
        _status = CallStatus.connecting;
        notifyListeners();
      })
      ..on('call_rejected', (data) {
        _status = CallStatus.rejected;
        _error = 'Call declined';
        notifyListeners();
        Future.delayed(const Duration(seconds: 2), () {
          _cleanupCall();
        });
      })
      ..on('call_room_state', (data) async {
        await _handleRoomState(Map<String, dynamic>.from(data));
      })
      ..on('call_participant_joined', (data) async {
        final username = data['username']?.toString() ?? '';
        if (username.isEmpty || username == _currentUsername) {
          return;
        }
        _updateParticipant(
          username,
          displayName: data['display_name']?.toString(),
          profileImage: data['profile_image']?.toString(),
        );
        await _createPeerConnection(username);
        await _sendOffer(username);
      })
      ..on('call_participant_left', (data) {
        final username = data['username']?.toString() ?? '';
        _participants.removeWhere((p) => p.username == username);
        _disposePeer(username);
        notifyListeners();
      })
      ..on('call_offer', (data) async {
        await _handleOffer(Map<String, dynamic>.from(data));
      })
      ..on('call_answer', (data) async {
        await _handleAnswer(Map<String, dynamic>.from(data));
      })
      ..on('call_ice_candidate', (data) async {
        await _handleIceCandidate(Map<String, dynamic>.from(data));
      })
      ..on('call_ended', (data) async {
        await _cleanupCall();
        _status = CallStatus.ended;
        notifyListeners();
      });

    _socket!.connect();
  }

  Future<void> startOutgoingCall(
    ChatUser user, {
    required bool videoCall,
    String? callerProfileImage,
  }) async {
    if (_socket == null || !_socket!.connected) {
      throw StateError('Call service is not connected');
    }

    _callId = DateTime.now().millisecondsSinceEpoch.toString();
    _roomId = 'call_$_callId';
    _callType = videoCall ? CallType.video : CallType.audio;
    _status = CallStatus.ringing;
    _isOutgoing = true;
    _callPartnerUsername = user.username;
    _currentProfileImage = callerProfileImage;
    _error = null;
    notifyListeners();

    await _prepareLocalMedia(videoCall);

    _socket!.emit('call_user', {
      'call_id': _callId,
      'room_id': _roomId,
      'caller_username': _currentUsername,
      'caller_display_name': _currentDisplayName,
      'caller_profile_image': _currentProfileImage,
      'callee_username': user.username,
      'callee_display_name': user.displayName.isNotEmpty
          ? user.displayName
          : user.username,
      'callee_profile_image': user.profileImage,
      'call_type': videoCall ? 'video' : 'audio',
    });

    await _joinRoom();
  }

  Future<void> inviteParticipant(ChatUser user) async {
    if (_roomId == null || _callId == null) return;
    _socket?.emit('call_add_participant', {
      'call_id': _callId,
      'room_id': _roomId,
      'inviter_username': _currentUsername,
      'inviter_display_name': _currentDisplayName,
      'invitee_username': user.username,
      'invitee_display_name': user.displayName.isNotEmpty
          ? user.displayName
          : user.username,
      'invitee_profile_image': user.profileImage,
      'call_type': isVideoCall ? 'video' : 'audio',
    });
  }

  Future<void> acceptIncomingCall() async {
    final incoming = _incomingCall;
    if (incoming == null) {
      print('❌ Cannot accept call: No incoming call found');
      return;
    }

    print('📡 Accepting call from ${incoming.callerUsername}...');
    try {
      print('  Call details:');
      print('    - ID: ${incoming.callId}');
      print('    - Room: ${incoming.roomId}');
      print('    - Type: ${incoming.callType}');
      print('    - Video: ${incoming.isVideo}');

      _callId = incoming.callId;
      _roomId = incoming.roomId;
      _callType = incoming.callType;
      _isOutgoing = false;
      _callPartnerUsername = incoming.callerUsername;
      _status = CallStatus.connecting;
      _error = null;
      notifyListeners();

      print('📹 Preparing media (video=${incoming.isVideo})...');
      await _prepareLocalMedia(incoming.isVideo);
      print('✅ Media prepared');

      print('📤 Emitting accept_call...');
      _socket?.emit('accept_call', {
        'call_id': _callId,
        'room_id': _roomId,
        'caller_username': incoming.callerUsername,
        'caller_display_name': incoming.callerDisplayName,
        'caller_profile_image': incoming.callerProfileImage,
        'callee_username': _currentUsername,
        'callee_display_name': _currentDisplayName,
        'callee_profile_image': _currentProfileImage,
      });

      print('🏠 Joining room $_roomId...');
      await _joinRoom();
      _incomingCall = null;
      print('✅ Successfully joined call room $_roomId');
      notifyListeners();
    } catch (e) {
      print('❌ Error accepting call: $e');
      print('   Stack trace: $e');
      _error = e.toString();
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectIncomingCall() async {
    final incoming = _incomingCall;
    if (incoming == null) return;

    _socket?.emit('reject_call', {
      'call_id': incoming.callId,
      'room_id': incoming.roomId,
      'caller_username': incoming.callerUsername,
      'callee_username': _currentUsername,
      'callee_display_name': _currentDisplayName,
      'reason': 'rejected',
      'call_type': incoming.callType == CallType.video ? 'video' : 'audio',
    });
    _incomingCall = null;
    _status = CallStatus.idle;
    notifyListeners();
  }

  Future<void> endCall() async {
    if (_roomId != null) {
      _socket?.emit('end_call', {
        'call_id': _callId,
        'room_id': _roomId,
        'username': _currentUsername,
      });
    }
    await _cleanupCall();
  }

  Future<void> _prepareLocalMedia(bool videoCall) async {
    print('🎬 Preparing local media... videoCall=$videoCall');
    final permissions = <Permission>[Permission.microphone];
    if (videoCall) {
      permissions.add(Permission.camera);
    }

    final result = await permissions.request();
    print('🔐 Permission result: $result');

    if ((result[Permission.microphone]?.isGranted ?? false) == false) {
      throw StateError('Microphone permission is required');
    }

    if (videoCall && (result[Permission.camera]?.isGranted ?? false) == false) {
      print('❌ Camera permission denied, falling back to audio only');
      throw StateError('Camera permission is required for video calls');
    }

    try {
      print('📞 Requesting getUserMedia...');
      final mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': videoCall
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : false,
      };

      print('📹 Media constraints: $mediaConstraints');
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      // Set to speaker by default for video calls usually, or use the _speakerOn value
      try {
        await Helper.setSpeakerphoneOn(_speakerOn);
      } catch (e) {
        print('Could not set speakerphone: $e');
      }
      print('✅ Got local media stream: ${_localStream?.id}');

      // Verify tracks
      final audioTracks = _localStream?.getAudioTracks() ?? [];
      final videoTracks = _localStream?.getVideoTracks() ?? [];
      print(
        '🔊 Audio tracks: ${audioTracks.length}, 🎥 Video tracks: ${videoTracks.length}',
      );

      _localRenderer.srcObject = _localStream;
      _audioEnabled = true;
      _videoEnabled = videoCall && videoTracks.isNotEmpty;
      _callType = videoCall ? CallType.video : CallType.audio;
      notifyListeners();
      print('✅ Local media preparation completed');
    } catch (e) {
      print('❌ Error preparing local media: $e');
      _error = 'Failed to access camera/microphone: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinRoom() async {
    if (_roomId == null) return;
    _socket?.emit('call_join_room', {
      'room_id': _roomId,
      'call_id': _callId,
      'username': _currentUsername,
      'display_name': _currentDisplayName,
      'profile_image': _currentProfileImage,
      'is_outgoing': _isOutgoing,
    });
  }

  Future<void> _handleRoomState(Map<String, dynamic> data) async {
    try {
      print('🏠 Received room state: $data');
      final participants = (data['participants'] as List? ?? [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();

      print('👥 Processing ${participants.length} participants');
      for (final participant in participants) {
        final username = participant['username']?.toString() ?? '';
        if (username.isEmpty || username == _currentUsername) continue;

        print('  - Adding participant: $username');
        _updateParticipant(
          username,
          displayName: participant['display_name']?.toString(),
          profileImage: participant['profile_image']?.toString(),
        );
        await _createPeerConnection(username);
      }

      _status = CallStatus.connected;
      notifyListeners();
      print('✅ Room state processed');
    } catch (e) {
      print('❌ Error handling room state: $e');
      _error = 'Failed to process room state: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUser) async {
    print('🔗 Creating peer connection for $remoteUser');
    final existing = _peerConnections[remoteUser];
    if (existing != null) {
      print('⚠️  Peer connection already exists for $remoteUser');
      return existing;
    }

    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
              'stun:stun2.l.google.com:19302',
            ],
          },
          {
            'urls': 'turn:openrelay.metered.ca:80',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:443',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ],
        'sdpSemantics': 'unified-plan',
      });

      print('✅ Peer connection created');

      pc.onIceCandidate = (candidate) {
        print('📤 ICE candidate: ${candidate.candidate?.substring(0, 50)}...');
        _socket?.emit('call_ice_candidate', {
          'to': remoteUser,
          'from': _currentUsername,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      pc.onTrack = (event) async {
        print(
          '📥 Track received: ${event.track.kind}, streams: ${event.streams.length}',
        );
        if (event.streams.isEmpty) {
          print('⚠️  Track event has no streams');
          return;
        }

        final renderer = _remoteRenderers[remoteUser];
        if (renderer == null) {
          print('🎥 Creating new renderer for $remoteUser');
          final newRenderer = RTCVideoRenderer();
          await newRenderer.initialize();
          _remoteRenderers[remoteUser] = newRenderer;
          newRenderer.srcObject = event.streams.first;
          print('✅ Remote video attached for $remoteUser');
        } else {
          print('📍 Using existing renderer for $remoteUser');
          renderer.srcObject = event.streams.first;
        }
        notifyListeners();
      };

      // Add local tracks
      print('🎙️  Adding local tracks to peer connection...');
      _localStream?.getTracks().forEach((track) {
        print('  - Adding track: ${track.kind} (enabled=${track.enabled})');
        pc.addTrack(track, _localStream!);
      });
      print('✅ Local tracks added');

      _peerConnections[remoteUser] = pc;
      print('✅ Peer connection stored for $remoteUser');
      return pc;
    } catch (e) {
      print('❌ Error creating peer connection: $e');
      _error = 'Failed to create peer connection: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _sendOffer(String remoteUser) async {
    try {
      print('📤 Sending offer to $remoteUser...');
      final pc = await _createPeerConnection(remoteUser);
      print('📝 Creating SDP offer...');
      final offer = await pc.createOffer();
      print('✅ Offer SDP created (${offer.sdp?.length ?? 0} chars)');

      await pc.setLocalDescription(offer);
      print('✅ Local description set');

      _socket?.emit('call_offer', {
        'to': remoteUser,
        'from': _currentUsername,
        'sdp': offer.sdp,
      });
      print('✅ Offer sent to $remoteUser');
    } catch (e) {
      print('❌ Error sending offer: $e');
      _error = 'Failed to send offer: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      final from = data['from']?.toString() ?? '';
      if (from.isEmpty) {
        print('❌ No sender in offer');
        return;
      }

      print(
        '📥 Received offer from $from (${data['sdp']?.toString().length ?? 0} chars)',
      );
      final pc = await _createPeerConnection(from);

      print('🔄 Setting remote description (offer)...');
      await pc.setRemoteDescription(
        RTCSessionDescription(data['sdp']?.toString(), 'offer'),
      );
      print('✅ Remote description set');

      print('📝 Creating SDP answer...');
      final answer = await pc.createAnswer();
      print('✅ Answer SDP created (${answer.sdp?.length ?? 0} chars)');

      await pc.setLocalDescription(answer);
      print('✅ Local description set');

      _socket?.emit('call_answer', {
        'to': from,
        'from': _currentUsername,
        'sdp': answer.sdp,
      });
      print('✅ Answer sent to $from');

      _status = CallStatus.connected;
      notifyListeners();
    } catch (e) {
      print('❌ Error handling offer: $e');
      _error = 'Failed to handle offer: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final from = data['from']?.toString() ?? '';
      if (from.isEmpty) {
        print('❌ No sender in answer');
        return;
      }

      print(
        '📥 Received answer from $from (${data['sdp']?.toString().length ?? 0} chars)',
      );
      final pc = _peerConnections[from];
      if (pc == null) {
        print('❌ No peer connection found for $from');
        return;
      }

      print('🔄 Setting remote description (answer)...');
      await pc.setRemoteDescription(
        RTCSessionDescription(data['sdp']?.toString(), 'answer'),
      );
      print('✅ Remote description set');

      _status = CallStatus.connected;
      notifyListeners();
      print('✅ Answer processed, call should be connecting now');
    } catch (e) {
      print('❌ Error handling answer: $e');
      _error = 'Failed to handle answer: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final from = data['from']?.toString() ?? '';
      if (from.isEmpty) return;

      final pc = _peerConnections[from];
      if (pc == null) {
        print('❌ No peer connection for ICE candidate from $from');
        return;
      }

      final candidate = RTCIceCandidate(
        data['candidate']?.toString(),
        data['sdpMid']?.toString(),
        data['sdpMLineIndex'],
      );

      await pc.addCandidate(candidate);
      print('✅ ICE candidate added from $from');
    } catch (e) {
      print('⚠️  Error adding ICE candidate: $e');
      // Don't throw for ICE errors - some are expected
    }
  }

  void _updateParticipant(
    String username, {
    String? displayName,
    String? profileImage,
  }) {
    final index = _participants.indexWhere((p) => p.username == username);
    if (index == -1) {
      _participants.add(
        CallParticipant(
          username: username,
          displayName: displayName ?? username,
          profileImage: profileImage,
          isLocal: username == _currentUsername,
        ),
      );
    } else {
      _participants[index] = _participants[index].copyWith(
        displayName: displayName,
        profileImage: profileImage,
      );
    }
    notifyListeners();
  }

  void _disposePeer(String username) {
    _peerConnections.remove(username)?.close();
    final renderer = _remoteRenderers.remove(username);
    renderer?.dispose();
  }

  Future<void> _cleanupCall() async {
    try {
      // Stop all local tracks to ensure the camera/mic are released.
      _localStream?.getTracks().forEach((t) {
        try {
          t.stop();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    if (_renderersReady) {
      _localRenderer.srcObject = null;
    }

    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    for (final renderer in _remoteRenderers.values) {
      await renderer.dispose();
    }
    _remoteRenderers.clear();

    _participants.clear();
    _incomingCall = null;
    _callId = null;
    _roomId = null;
    _callPartnerUsername = null;
    _status = CallStatus.idle;
    _audioEnabled = true;
    _videoEnabled = true;
    _speakerOn = true;
    _error = null;
    _isOutgoing = false;
    notifyListeners();
  }

  void toggleMute() {
    _audioEnabled = !_audioEnabled;
    _localStream?.getAudioTracks().forEach(
      (track) => track.enabled = _audioEnabled,
    );
    notifyListeners();
  }

  void toggleCamera() {
    _videoEnabled = !_videoEnabled;
    _localStream?.getVideoTracks().forEach(
      (track) => track.enabled = _videoEnabled,
    );
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (_) {}
    notifyListeners();
  }

  void disconnect() {
    _cleanupCall();
    _socket?.disconnect();
    _socket = null;
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    try {
      _localStream?.getTracks().forEach((t) {
        try {
          t.stop();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      _localStream?.dispose();
    } catch (_) {}
    super.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
