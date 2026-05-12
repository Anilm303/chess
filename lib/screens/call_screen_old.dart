import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../models/message_model.dart';
import '../services/call_service.dart';
import '../services/message_service.dart';
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

  Future<void> _inviteParticipant() async {
    final callService = context.read<CallService>();
    final messageService = context.read<MessageService>();

    final currentParticipants = callService.participants
        .map((participant) => participant.username)
        .toSet();

    final candidates = messageService.allUsers
        .where(
          (user) =>
              user.username != callService.currentUsername &&
              !currentParticipants.contains(user.username),
        )
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No additional users available')),
      );
      return;
    }

    final selected = await showModalBottomSheet<ChatUser>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = candidates[index];
              return ListTile(
                leading:
                    user.profileImage != null && user.profileImage!.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: MemoryImage(
                          base64Decode(user.profileImage!),
                        ),
                      )
                    : CircleAvatar(child: Text(user.initials)),
                title: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName
                      : user.username,
                ),
                subtitle: Text('@${user.username}'),
                onTap: () => Navigator.of(sheetContext).pop(user),
              );
            },
          ),
        );
      },
    );

    // if (selected != null) {
    //   await callService.inviteParticipant(selected);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, _) {
        if (callService.status == CallStatus.idle ||
            callService.status == CallStatus.ended ||
            callService.status == CallStatus.rejected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed && mounted) Navigator.of(context).maybePop();
          });
        }

        final isVideo = callService.isVideoCall;
        final remoteRenderers = callService.remoteRendererEntries.toList();
        final participants = callService.participants;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Stack(
            children: [
              // Constrain the main remote video area so it doesn't overflow
              // on large laptop screens. Single participant gets a large
              // centered video with 16:9 aspect; multi-party uses a
              // constrained GridView.
              if (remoteRenderers.isNotEmpty)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          (MediaQuery.of(context).size.width * 0.95) > 1000
                          ? 1000
                          : (MediaQuery.of(context).size.width * 0.95),
                    ),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final w = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : MediaQuery.of(context).size.width * 0.9;
                        if (remoteRenderers.length == 1) {
                          final height = (w * 9 / 16).clamp(
                            240.0,
                            MediaQuery.of(context).size.height * 0.8,
                          );
                          return SizedBox(
                            width: w,
                            height: height,
                            child: _buildRemoteSingle(
                              remoteRenderers.first.value,
                            ),
                          );
                        }
                        return ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: w),
                          child: _buildRemoteGrid(remoteRenderers),
                        );
                      },
                    ),
                  ),
                )
              else
                _buildPlaceholder(callService),

              if (isVideo && callService.videoEnabled)
                Positioned(
                  top: 48,
                  right: 16,
                  child: Container(
                    width: 110,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RTCVideoView(
                        callService.localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 56,
                left: 20,
                right: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participants.isEmpty
                          ? 'Calling...'
                          : participants.first.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(callService.status),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 34,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 14,
                        children: [
                          _buildControlButton(
                            onPressed: () => callService.toggleMute(),
                            icon: callService.audioEnabled
                                ? Icons.mic
                                : Icons.mic_off,
                            label: callService.audioEnabled ? 'Mute' : 'Unmute',
                            color: callService.audioEnabled
                                ? Colors.white24
                                : Colors.white,
                            iconColor: callService.audioEnabled
                                ? Colors.white
                                : Colors.black,
                          ),
                          if (isVideo)
                            _buildControlButton(
                              onPressed: () => callService.toggleCamera(),
                              icon: callService.videoEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              label: callService.videoEnabled
                                  ? 'Camera Off'
                                  : 'Camera On',
                              color: callService.videoEnabled
                                  ? Colors.white24
                                  : Colors.white,
                              iconColor: callService.videoEnabled
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          if (isVideo)
                            _buildControlButton(
                              onPressed: () => callService.switchCamera(),
                              icon: Icons.flip_camera_ios,
                              label: 'Switch',
                            ),
                          // _buildControlButton(
                          //   onPressed: _inviteParticipant,
                          //   icon: Icons.person_add_alt_1,
                          //   label: 'Add',
                          // ),
                          _buildControlButton(
                            onPressed: () => callService.toggleSpeaker(),
                            icon: callService.speakerOn
                                ? Icons.volume_up
                                : Icons.volume_mute,
                            label: 'Speaker',
                          ),
                          _buildControlButton(
                            onPressed: () => callService.endCall(),
                            icon: Icons.call_end,
                            label: 'End',
                            color: Colors.red,
                            iconColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemoteGrid(List<MapEntry<String, RTCVideoRenderer>> renderers) {
    final crossAxisCount = renderers.length > 1 ? 2 : 1;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      childAspectRatio: 0.85,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.fromLTRB(12, 100, 12, 110),
      children: renderers
          .map(
            (entry) => Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: RTCVideoView(
                  entry.value,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRemoteSingle(RTCVideoRenderer renderer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(CallService callService) {
    final invitation = callService.incomingCall;
    final label = invitation?.callerDisplayName.isNotEmpty == true
        ? invitation!.callerDisplayName
        : invitation?.callerUsername ?? 'Connecting...';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: MessengerColors.messengerGradient,
            ),
            child: const Icon(Icons.person, size: 84, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusText(callService.status),
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    Color color = Colors.white24,
    Color iconColor = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.ringing:
        return 'Calling...';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return 'Connected';
      case CallStatus.rejected:
        return 'Declined';
      case CallStatus.failed:
        return 'Failed';
      case CallStatus.ended:
        return 'Ended';
      default:
        return '';
    }
  }
}
