import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../services/call_service.dart';
import '../theme/colors.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, _) {
        // Auto-close on call end
        if (callService.status == CallStatus.idle ||
            callService.status == CallStatus.ended ||
            callService.status == CallStatus.rejected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed && mounted) {
              Navigator.of(context).maybePop();
            }
          });
        }

        final isVideo = callService.isVideoCall;
        final remoteRenderers = callService.remoteRendererEntries.toList();
        final participants = callService.participants;

        return WillPopScope(
          onWillPop: () async {
            if (callService.isConnected) {
              await callService.endCall();
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: Stack(
              children: [
                // Remote video or placeholder
                if (remoteRenderers.isNotEmpty)
                  _buildRemoteVideo(remoteRenderers)
                else
                  _buildNoRemoteVideo(callService, participants),

                // Local video preview (top-right corner)
                if (isVideo && callService.videoEnabled)
                  _buildLocalPreview(callService),

                // Header with caller info
                _buildHeader(callService, participants),

                // Control buttons at bottom
                _buildControlPanel(context, callService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteVideo(List<MapEntry<String, RTCVideoRenderer>> renderers) {
    if (renderers.length == 1) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: RTCVideoView(
          renderers.first.value,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    // Multi-party grid
    return Container(
      color: const Color(0xFF1A1A1A),
      child: GridView.count(
        crossAxisCount: 2,
        children: renderers
            .map(
              (entry) => Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    entry.value,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNoRemoteVideo(
    CallService callService,
    List<CallParticipant> participants,
  ) {
    final displayName = participants.isNotEmpty
        ? participants.first.displayName
        : callService.incomingCall?.callerDisplayName ??
              callService.incomingCall?.callerUsername ??
              'Connecting...';

    final profileImage = participants.isNotEmpty
        ? participants.first.profileImage
        : callService.incomingCall?.callerProfileImage;

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2A2A),
                border: Border.all(
                  color: MessengerColors.messengerBlue,
                  width: 2,
                ),
              ),
              child: _buildAvatarWidget(profileImage, displayName),
            ),
            const SizedBox(height: 32),
            // Name
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Status
            Text(
              _getStatusText(callService.status),
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            if (callService.isConnected) ...[
              const SizedBox(height: 16),
              Text(
                _formatDuration(callService.elapsedTime),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String? profileImage, String displayName) {
    if (profileImage != null && profileImage.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(70),
          child: Image.memory(base64Decode(profileImage), fit: BoxFit.cover),
        );
      } catch (e) {
        debugPrint('Error loading avatar: $e');
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: MessengerColors.messengerGradient,
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalPreview(CallService callService) {
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        width: 100,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
          color: const Color(0xFF2A2A2A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: RTCVideoView(
            callService.localRenderer,
            mirror: true,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    CallService callService,
    List<CallParticipant> participants,
  ) {
    final displayName = participants.isNotEmpty
        ? participants.first.displayName
        : callService.incomingCall?.callerDisplayName ?? 'Calling...';

    return Positioned(
      top: 48,
      left: 20,
      right: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusText(callService.status),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          if (callService.isConnected) ...[
            const SizedBox(height: 2),
            Text(
              _formatDuration(callService.elapsedTime),
              style: TextStyle(
                color: Colors.green.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, CallService callService) {
    final isVideo = callService.isVideoCall;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Control buttons grid
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildControlButton(
                    icon: callService.audioEnabled ? Icons.mic : Icons.mic_off,
                    label: callService.audioEnabled ? 'Mute' : 'Unmute',
                    color: callService.audioEnabled
                        ? Colors.grey[800]
                        : Colors.red.withOpacity(0.3),
                    onPressed: () => callService.toggleMute(),
                  ),
                  if (isVideo)
                    _buildControlButton(
                      icon: callService.videoEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: callService.videoEnabled ? 'Camera' : 'Camera Off',
                      color: callService.videoEnabled
                          ? Colors.grey[800]
                          : Colors.red.withOpacity(0.3),
                      onPressed: () => callService.toggleCamera(),
                    ),
                  if (isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      label: 'Flip',
                      color: Colors.grey[800],
                      onPressed: () => callService.switchCamera(),
                    ),
                  _buildControlButton(
                    icon: callService.speakerOn
                        ? Icons.volume_up
                        : Icons.volume_off,
                    label: callService.speakerOn ? 'Speaker' : 'Speaker Off',
                    color: callService.speakerOn
                        ? Colors.grey[800]
                        : Colors.orange.withOpacity(0.3),
                    onPressed: () => callService.toggleSpeaker(),
                  ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    color: Colors.red,
                    textColor: Colors.white,
                    onPressed: () async {
                      await callService.endCall();
                      if (mounted) {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    Color? color,
    Color textColor = Colors.white70,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color ?? Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.rejected:
        return 'Call declined';
      case CallStatus.failed:
        return 'Call failed';
      case CallStatus.ended:
        return 'Call ended';
      default:
        return 'Idle';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
