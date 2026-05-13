import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../navigation/app_navigator.dart';
import '../theme/colors.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  CallInvitation? _callSnapshot;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final callService = context.read<CallService>();
      _callSnapshot = callService.incomingCall;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (context, callService, _) {
        final call = callService.incomingCall;
        if (callService.status == CallStatus.idle ||
            callService.status == CallStatus.ended ||
            callService.status == CallStatus.rejected) {
          if (!_dismissScheduled) {
            _dismissScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
        } else {
          _dismissScheduled = false;
        }

        final activeCall = call ?? _callSnapshot;

        final displayName = (activeCall?.callerDisplayName.isNotEmpty ?? false)
            ? activeCall!.callerDisplayName
            : activeCall?.callerUsername ?? 'Unknown';

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 48),
                // Header
                Column(
                  children: [
                    Text(
                      activeCall?.isVideo == true ? 'Video Call' : 'Voice Call',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Avatar
                    ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.95,
                        end: 1.05,
                      ).animate(_scaleController),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A2A),
                          border: Border.all(
                            color: MessengerColors.messengerBlue,
                            width: 3,
                          ),
                        ),
                        child: _buildAvatar(
                          activeCall?.callerProfileImage,
                          displayName,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Caller name
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Status
                    Text(
                      activeCall?.isVideo == true
                          ? 'Incoming video call'
                          : 'Incoming call',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject button
                      GestureDetector(
                        onTap: () async {
                          await callService.rejectIncomingCall();
                          if (mounted) {
                            Navigator.of(context).maybePop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Decline',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Accept button
                      GestureDetector(
                        onTap: () async {
                          try {
                            await callService.acceptIncomingCall();
                            if (mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const CallScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error accepting call: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? profileImage, String displayName) {
    if (profileImage != null && profileImage.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(60),
          child: Image.memory(base64Decode(profileImage), fit: BoxFit.cover),
        );
      } catch (e) {
        debugPrint('Error loading profile image: $e');
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
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
