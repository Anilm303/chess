import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

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
  bool _localMediaPrepared = false;
  DateTime? _callStartTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _callDurationTimer;

  CallInvitation? _incomingCall;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Set<RTCVideoRenderer> _initializedRenderers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Set<String> _offeredPeers = <String>{};
  final Set<String> _offerInProgress = <String>{};
  final List<CallParticipant> _participants = [];
  String? _error;

  // Getters
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
  Duration get elapsedTime => _elapsedTime;

  Future<void> connect({
    required String accessToken,
    required String username,
    required String displayName,
  }) async {
    _log('🔗 Connecting to call service...');
    _accessToken = accessToken;
    _currentUsername = username;
    _currentDisplayName = displayName;

    if (_socket?.connected == true) {
      _log('⚠️ Socket already connected');
      return;
    }

    if (!_renderersReady) {
      try {
        await _localRenderer.initialize();
        _renderersReady = true;
        _log('✅ Local renderer initialized');
      } catch (e) {
        _log('❌ Failed to initialize renderer: $e');
      }
    }

    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    _log('📡 Connecting to: $baseUrl');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setQuery({'token': accessToken})
          .build(),
    );

    _setupSocketListeners();
    _socket!.connect();
  }

  void _setupSocketListeners() {
    _socket!
      ..onConnect((_) {
        _log('✅ Socket connected (id=${_socket!.id})');
      })
      ..onConnectError((err) {
        _log('❌ Socket connect error: $err');
        _error = 'Connection failed: $err';
        notifyListeners();
      })
      ..onConnectTimeout((_) {
        _log('⏱️ Socket connect timeout');
        _error = 'Connection timeout';
        notifyListeners();
      })
      ..onDisconnect((_) {
        _log('📴 Socket disconnected');
        if (_status != CallStatus.ended && _status != CallStatus.idle) {
          _status = CallStatus.ended;
          notifyListeners();
        }
      })
      ..on('incoming_call', _handleIncomingCall)
      ..on('call_accepted', _handleCallAccepted)
      ..on('call_rejected', _handleCallRejected)
      ..on('call_room_state', _handleRoomState)
      ..on('call_participant_joined', _handleParticipantJoined)
      ..on('call_participant_left', _handleParticipantLeft)
      ..on('call_offer', _handleOffer)
      ..on('call_answer', _handleAnswer)
      ..on('call_ice_candidate', _handleIceCandidate)
      ..on('call_ended', _handleCallEnded);
  }

  void _handleIncomingCall(dynamic data) {
    _log('📞 Incoming call event received');
    try {
      final callData = Map<String, dynamic>.from(data as Map);
      _incomingCall = CallInvitation.fromJson(callData);
      _status = CallStatus.ringing;
      _error = null;
      _log('🔔 Call status: RINGING from ${_incomingCall?.callerUsername}');
      notifyListeners();
    } catch (e) {
      _log('❌ Error handling incoming_call: $e');
    }
  }

  Future<void> _handleCallAccepted(dynamic data) async {
    _log('✅ Call accepted by peer');
    _status = CallStatus.connecting;
    notifyListeners();

    try {
      final map = Map<String, dynamic>.from(data as Map);
      final remoteUser = map['callee_username']?.toString() == _currentUsername
          ? (map['caller_username']?.toString() ?? '')
          : (map['callee_username']?.toString() ?? '');

      if (remoteUser.isNotEmpty && remoteUser != _currentUsername) {
        _log('📡 call_accepted fallback: create/send offer to $remoteUser');
        _updateParticipant(
          remoteUser,
          displayName: map['callee_display_name']?.toString(),
          profileImage: map['callee_profile_image']?.toString(),
        );
        await _createPeerConnection(remoteUser);
        await _sendOffer(remoteUser);
      }
    } catch (e) {
      _log('⚠️ call_accepted fallback failed: $e');
    }
  }

  void _handleCallRejected(dynamic data) {
    _log('❌ Call rejected by peer');
    _status = CallStatus.rejected;
    _error = 'Call declined';
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      _cleanupCall();
    });
  }

  void _handleParticipantJoined(dynamic data) async {
    final username = (data as Map?)?['username']?.toString() ?? '';
    if (username.isEmpty || username == _currentUsername) return;
    _log('👤 Participant joined: $username');
    _updateParticipant(
      username,
      displayName: (data as Map?)?['display_name']?.toString(),
      profileImage: (data as Map?)?['profile_image']?.toString(),
    );
    try {
      await _createPeerConnection(username);
      if (_isOutgoing) {
        await _sendOffer(username);
      }
    } catch (e) {
      _log('❌ Error in participant join: $e');
    }
  }

  void _handleParticipantLeft(dynamic data) {
    final username = (data as Map?)?['username']?.toString() ?? '';
    _log('👤 Participant left: $username');
    _participants.removeWhere((p) => p.username == username);
    _disposePeer(username);
    notifyListeners();
  }

  Future<void> _handleRoomState(dynamic data) async {
    _log('🏠 Room state received');
    try {
      final roomData = Map<String, dynamic>.from(data as Map);
      final participants = (roomData['participants'] as List? ?? [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();

      _log('👥 Processing ${participants.length} participants');
      for (final participant in participants) {
        final username = participant['username']?.toString() ?? '';
        if (username.isEmpty || username == _currentUsername) continue;
        _log('  ➕ Adding: $username');
        _updateParticipant(
          username,
          displayName: participant['display_name']?.toString(),
          profileImage: participant['profile_image']?.toString(),
        );
        try {
          await _createPeerConnection(username);
          // Fallback: caller also sends offer from room-state to avoid
          // relying only on participant-joined event ordering.
          if (_isOutgoing) {
            await _sendOffer(username);
          }
        } catch (e) {
          _log('⚠️ Error creating peer for $username: $e');
        }
      }
      notifyListeners();
      _log('✅ Room state processed');
    } catch (e) {
      _log('❌ Error handling room state: $e');
    }
  }

  Future<void> _handleOffer(dynamic data) async {
    try {
      final offerData = Map<String, dynamic>.from(data as Map);
      final from = offerData['from']?.toString() ?? '';
      if (from.isEmpty) {
        _log('❌ Offer with no sender');
        return;
      }

      _log('📥 Offer from $from');
      final pc = await _createPeerConnection(from);

      _log('🔄 Setting remote offer...');
      await pc.setRemoteDescription(
        RTCSessionDescription(offerData['sdp']?.toString() ?? '', 'offer'),
      );

      _log('📝 Creating answer...');
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socket?.emit('call_answer', {
        'to': from,
        'from': _currentUsername,
        'sdp': answer.sdp,
      });
      _log('✅ Answer sent to $from');
      notifyListeners();
    } catch (e) {
      _log('❌ Error handling offer: $e');
      _error = 'Failed to handle offer: $e';
      _status = CallStatus.failed;
      notifyListeners();
    }
  }

  Future<void> _handleAnswer(dynamic data) async {
    try {
      final answerData = Map<String, dynamic>.from(data as Map);
      final from = answerData['from']?.toString() ?? '';
      if (from.isEmpty) {
        _log('❌ Answer with no sender');
        return;
      }

      _log('📥 Answer from $from');
      final pc = _peerConnections[from];
      if (pc == null) {
        _log('❌ No peer connection for $from');
        return;
      }

      _log('🔄 Setting remote answer...');
      await pc.setRemoteDescription(
        RTCSessionDescription(answerData['sdp']?.toString() ?? '', 'answer'),
      );
      if (_status != CallStatus.connected) {
        _status = CallStatus.connected;
        _startCallDurationTimer();
      }
      notifyListeners();
      _log('✅ Answer processed');
    } catch (e) {
      _log('❌ Error handling answer: $e');
      _error = 'Failed to handle answer: $e';
      _status = CallStatus.failed;
      notifyListeners();
    }
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    try {
      final iceData = Map<String, dynamic>.from(data as Map);
      final from = iceData['from']?.toString() ?? '';
      if (from.isEmpty) return;

      final pc = _peerConnections[from];
      if (pc == null) {
        _log('⚠️ No peer for ICE from $from');
        return;
      }

      final candidate = RTCIceCandidate(
        iceData['candidate']?.toString(),
        iceData['sdpMid']?.toString(),
        iceData['sdpMLineIndex'] as int?,
      );

      await pc.addCandidate(candidate);
      _log('✅ ICE candidate added');
    } catch (e) {
      _log('⚠️ Error adding ICE: $e');
    }
  }

  void _handleCallEnded(dynamic data) async {
    _log('📞 Call ended');
    await _cleanupCall();
    _status = CallStatus.ended;
    notifyListeners();
  }

  Future<void> startOutgoingCall(
    ChatUser user, {
    required bool videoCall,
    String? callerProfileImage,
  }) async {
    if (_socket == null || !_socket!.connected) {
      throw StateError('Call service is not connected');
    }

    _log(
      '📞 Starting ${videoCall ? 'video' : 'audio'} call to ${user.username}',
    );
    _callId = DateTime.now().millisecondsSinceEpoch.toString();
    _roomId = 'call_$_callId';
    _callType = videoCall ? CallType.video : CallType.audio;
    _status = CallStatus.ringing;
    _isOutgoing = true;
    _callPartnerUsername = user.username;
    _currentProfileImage = callerProfileImage;
    _error = null;
    notifyListeners();

    try {
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

      _log('✅ Call initiated to ${user.username}');
      await _joinRoom();
    } catch (e) {
      _log('❌ Error starting call: $e');
      _error = e.toString();
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> acceptIncomingCall() async {
    final incoming = _incomingCall;
    if (incoming == null) {
      _log('❌ No incoming call to accept');
      return;
    }

    _log('✅ Accepting call from ${incoming.callerUsername}');
    try {
      _callId = incoming.callId;
      _roomId = incoming.roomId;
      _callType = incoming.callType;
      _isOutgoing = false;
      _callPartnerUsername = incoming.callerUsername;
      _status = CallStatus.connecting;
      _error = null;
      notifyListeners();

      _log('📹 Preparing media for ${incoming.isVideo ? 'video' : 'audio'}...');
      await _prepareLocalMedia(incoming.isVideo);

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

      _log('🏠 Joining room $_roomId');
      await _joinRoom();
      _incomingCall = null;
      _log('✅ Call accepted and room joined');
      notifyListeners();
    } catch (e) {
      _log('❌ Error accepting call: $e');
      _error = e.toString();
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectIncomingCall() async {
    final incoming = _incomingCall;
    if (incoming == null) return;

    _log('❌ Rejecting call from ${incoming.callerUsername}');
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
    _log('📞 Ending call');
    if (_roomId != null) {
      _socket?.emit('end_call', {
        'call_id': _callId,
        'room_id': _roomId,
        'username': _currentUsername,
      });
    }
    await _cleanupCall();
  }

  Future<void> toggleMute() async {
    _audioEnabled = !_audioEnabled;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _audioEnabled;
    });
    _log(_audioEnabled ? '🔊 Unmuted' : '🔇 Muted');
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    if (!isVideoCall) return;
    _videoEnabled = !_videoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _videoEnabled;
    });
    _log(_videoEnabled ? '📹 Camera on' : '📹 Camera off');
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (!isVideoCall) return;
    try {
      _localStream?.getVideoTracks().forEach((track) async {
        await track.switchCamera();
      });
      _log('📱 Camera switched');
    } catch (e) {
      _log('❌ Camera switch failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
      _log(_speakerOn ? '🔊 Speaker on' : '🔇 Speaker off');
    } catch (e) {
      _log('❌ Speaker toggle failed: $e');
    }
    notifyListeners();
  }

  Future<void> _prepareLocalMedia(bool videoCall) async {
    _log('🎬 Preparing local media (video=$videoCall)');

    final permissions = <Permission>[Permission.microphone];
    if (videoCall) {
      permissions.add(Permission.camera);
    }

    final result = await permissions.request();
    _log('🔐 Permissions: $result');

    if ((result[Permission.microphone]?.isGranted ?? false) == false) {
      throw StateError('Microphone permission is required');
    }

    if (videoCall && (result[Permission.camera]?.isGranted ?? false) == false) {
      throw StateError('Camera permission is required for video calls');
    }

    try {
      _log('📞 Getting user media...');
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

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _log('✅ Media stream obtained');

      final audioTracks = _localStream?.getAudioTracks() ?? [];
      final videoTracks = _localStream?.getVideoTracks() ?? [];
      _log('🎙️ Audio: ${audioTracks.length}, 📹 Video: ${videoTracks.length}');

      await _localRenderer.initialize();
      _initializedRenderers.add(_localRenderer);
      try {
        if (_initializedRenderers.contains(_localRenderer)) {
          _localRenderer.srcObject = _localStream;
        } else {
          _log(
            '⚠️ Local renderer not marked initialized, skipping srcObject set',
          );
        }
      } catch (e) {
        _log('⚠️ Could not set local renderer srcObject: $e');
      }

      _audioEnabled = true;
      _videoEnabled = videoCall && videoTracks.isNotEmpty;
      _localMediaPrepared = true;
      _log('✅ Local media ready');
    } catch (e) {
      _log('❌ Media error: $e');
      _error = 'Failed to access camera/microphone: $e';
      _status = CallStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _joinRoom() async {
    if (_roomId == null) return;
    _log('🏠 Joining room $_roomId');
    _socket?.emit('call_join_room', {
      'room_id': _roomId,
      'call_id': _callId,
      'username': _currentUsername,
      'display_name': _currentDisplayName,
      'profile_image': _currentProfileImage,
      'is_outgoing': _isOutgoing,
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUser) async {
    _log('🔗 Creating peer connection for $remoteUser');

    if (_peerConnections.containsKey(remoteUser)) {
      _log('⚠️ Peer already exists for $remoteUser');
      return _peerConnections[remoteUser]!;
    }

    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
          {
            'urls': ['stun:stun1.l.google.com:19302'],
          },
          // Added TURN Server for better connectivity
          {
            'urls': [
              'turn:openrelay.metered.ca:80',
              'turn:openrelay.metered.ca:443',
              'turn:openrelay.metered.ca:443?transport=tcp',
            ],
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ],
        'sdpSemantics': 'unified-plan',
      });

      pc.onIceConnectionState = (state) {
        _log('🧊 ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          if (_status != CallStatus.connected) {
            _status = CallStatus.connected;
            _startCallDurationTimer();
            notifyListeners();
          }
        }
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _log(
            '⚠️ Connection lost or failed. Triggering reconnect logic if possible.',
          );
          // You could add a reconnect event emit here.
        }
      };

      pc.onConnectionState = (state) {
        _log('🔌 PeerConnection state: $state');
      };

      pc.onSignalingState = (state) {
        _log('📶 Signaling state: $state');
      };

      pc.onAddStream = (stream) async {
        _log(
          '📥 onAddStream for $remoteUser (tracks: ${stream.getTracks().length}, audio: ${stream.getAudioTracks().length}, video: ${stream.getVideoTracks().length})',
        );
        await _attachRemoteStream(remoteUser, stream, source: 'onAddStream');
      };

      pc.onIceCandidate = (candidate) {
        _log('🧊 ICE candidate');
        _socket?.emit('call_ice_candidate', {
          'to': remoteUser,
          'from': _currentUsername,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      pc.onTrack = (event) async {
        _log(
          '📥 Track received: ${event.track.kind}, enabled=${event.track.enabled}',
        );
        _log('   Streams count: ${event.streams.length}');
        _log('   Track ID: ${event.track.id}');

        if (!_remoteRenderers.containsKey(remoteUser)) {
          _log('🎥 Creating renderer for $remoteUser');
          final renderer = RTCVideoRenderer();
          try {
            await renderer.initialize();
            _remoteRenderers[remoteUser] = renderer;
            _initializedRenderers.add(renderer);
            _log('✅ Renderer initialized for $remoteUser');
          } catch (e) {
            _log('❌ Failed to initialize renderer: $e');
            return;
          }
        }

        try {
          if (event.streams.isEmpty) {
            _log('⚠️ No streams in track event for ${event.track.kind}');
            final syntheticStream = await createLocalMediaStream(
              'remote_$remoteUser',
            );
            try {
              syntheticStream.addTrack(event.track);
              _log(
                '✅ Created synthetic stream and attached ${event.track.kind}',
              );
            } catch (e) {
              _log('❌ Failed to attach track to synthetic stream: $e');
              return;
            }
            await _attachRemoteStream(
              remoteUser,
              syntheticStream,
              source: 'onTrack/synthetic',
            );
          } else {
            await _attachRemoteStream(
              remoteUser,
              event.streams.first,
              source: 'onTrack',
            );
          }
        } catch (e) {
          _log('❌ Error setting srcObject: $e');
        }

        _updateParticipant(remoteUser);
        if (_status != CallStatus.connected) {
          _status = CallStatus.connected;
          _startCallDurationTimer();
        }
        notifyListeners();
      };

      // Add local tracks
      _log('🎙️ Adding local tracks...');
      final tracks = _localStream?.getTracks() ?? [];
      for (final track in tracks) {
        _log('   Adding ${track.kind} track (enabled=${track.enabled})');
        try {
          pc.addTrack(track, _localStream!);
        } catch (e) {
          _log('   ⚠️ Error adding track: $e');
        }
      }
      _log('✅ Added ${tracks.length} tracks');

      _peerConnections[remoteUser] = pc;
      _log('✅ Peer created for $remoteUser');
      return pc;
    } catch (e) {
      _log('❌ Peer creation failed: $e');
      rethrow;
    }
  }

  Future<void> _attachRemoteStream(
    String remoteUser,
    MediaStream stream, {
    required String source,
  }) async {
    final renderer = _remoteRenderers[remoteUser];
    if (renderer == null) {
      _log('⚠️ No renderer exists for $remoteUser while attaching stream');
      return;
    }

    _log(
      '📦 Attaching remote stream from $source for $remoteUser (tracks: ${stream.getTracks().length}, audio: ${stream.getAudioTracks().length}, video: ${stream.getVideoTracks().length})',
    );
    _log(
      '   Track enabled states: audio=${stream.getAudioTracks().map((t) => t.enabled).toList()}, video=${stream.getVideoTracks().map((t) => t.enabled).toList()}',
    );

    if (_initializedRenderers.contains(renderer)) {
      renderer.srcObject = stream;
      _log('✅ srcObject set for $remoteUser via $source');
      notifyListeners();
    } else {
      _log('❌ Renderer not in initialized set');
    }
  }

  Future<void> _sendOffer(String remoteUser) async {
    try {
      if (_offeredPeers.contains(remoteUser)) {
        _log('ℹ️ Offer already sent to $remoteUser, skipping duplicate');
        return;
      }
      if (_offerInProgress.contains(remoteUser)) {
        _log(
          'ℹ️ Offer already in progress for $remoteUser, skipping duplicate',
        );
        return;
      }
      _offerInProgress.add(remoteUser);
      _log('📤 Sending offer to $remoteUser');
      final pc = _peerConnections[remoteUser];
      if (pc == null) {
        _log('❌ No peer for offer to $remoteUser');
        _offerInProgress.remove(remoteUser);
        return;
      }

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _offeredPeers.add(remoteUser);

      _socket?.emit('call_offer', {
        'to': remoteUser,
        'from': _currentUsername,
        'sdp': offer.sdp,
      });
      _log('✅ Offer sent');
    } catch (e) {
      _log('❌ Offer failed: $e');
    } finally {
      _offerInProgress.remove(remoteUser);
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
        ),
      );
      _log('➕ Participant added: $username');
    } else if (displayName != null || profileImage != null) {
      final p = _participants[index];
      _participants[index] = CallParticipant(
        username: p.username,
        displayName: displayName ?? p.displayName,
        profileImage: profileImage ?? p.profileImage,
      );
    }
  }

  void _disposePeer(String username) {
    _log('🗑️ Disposing peer: $username');
    try {
      _peerConnections[username]?.dispose();
    } catch (e) {
      _log('⚠️ Error disposing peer connection for $username: $e');
    }
    _peerConnections.remove(username);
    _offeredPeers.remove(username);
    _offerInProgress.remove(username);

    try {
      _remoteRenderers[username]?.dispose();
    } catch (e) {
      _log('⚠️ Error disposing remote renderer for $username: $e');
    }
    _remoteRenderers.remove(username);
  }

  Future<void> _cleanupCall() async {
    _log('🧹 Cleaning up call');
    _callDurationTimer?.cancel();
    _callStartTime = null;
    _elapsedTime = Duration.zero;

    // Dispose peer connections
    for (final pc in _peerConnections.values) {
      try {
        await pc.dispose();
      } catch (e) {
        _log('⚠️ Error disposing peer connection: $e');
      }
    }
    _peerConnections.clear();
    _offeredPeers.clear();
    _offerInProgress.clear();

    // Dispose remote renderers safely
    for (final renderer in _remoteRenderers.values) {
      try {
        await renderer.dispose();
        _initializedRenderers.remove(renderer);
      } catch (e) {
        _log('⚠️ Error disposing remote renderer: $e');
      }
    }
    _remoteRenderers.clear();

    // Stop media stream
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          await track.stop();
        } catch (e) {
          _log('⚠️ Error stopping track: $e');
        }
      }
      try {
        await _localStream!.dispose();
      } catch (e) {
        _log('⚠️ Error disposing stream: $e');
      }
      _localStream = null;
    }

    _participants.clear();
    _localMediaPrepared = false;
    _incomingCall = null;
    _status = CallStatus.idle;
    _callId = null;
    _roomId = null;
    _error = null;
    notifyListeners();
    _log('✅ Cleanup complete');
  }

  void _startCallDurationTimer() {
    if (_callStartTime != null) return;
    _callStartTime = DateTime.now();
    _callDurationTimer?.cancel();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedTime = DateTime.now().difference(_callStartTime!);
      notifyListeners();
    });
    _log('⏱️ Call timer started');
  }

  Future<void> disconnect() async {
    _log('📴 Disconnecting call service');
    await _cleanupCall();
    // Note: Do NOT set srcObject here. _cleanupCall() has already cleaned up
    // the stream. Trying to set srcObject after cleanup can cause renderer errors.
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _log(String message) {
    debugPrint('🎤 CallService: $message');
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
    super.dispose();
  }
}
