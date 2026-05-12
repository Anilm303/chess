import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../navigation/app_navigator.dart';
import '../services/call_service.dart';
import '../theme/colors.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callService = context.watch<CallService>();
    final invitation = callService.incomingCall;

    if (invitation == null ||
        callService.status == CallStatus.ended ||
        callService.status == CallStatus.idle ||
        callService.status == CallStatus.rejected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = rootNavigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      });
      return const SizedBox.shrink();
    }

    final isVideo = invitation.callType == CallType.video;

    return Material(
      color: Colors.black.withOpacity(0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MessengerColors.messengerGradient,
                  boxShadow: [
                    BoxShadow(
                      color: MessengerColors.messengerBlue.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child:
                    invitation.callerProfileImage != null &&
                        invitation.callerProfileImage!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(invitation.callerProfileImage!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        isVideo ? Icons.videocam : Icons.call,
                        color: Colors.white,
                        size: 54,
                      ),
              ),
              const SizedBox(height: 28),
              Text(
                invitation.callerDisplayName.isNotEmpty
                    ? invitation.callerDisplayName
                    : invitation.callerUsername,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isVideo ? 'Incoming video call' : 'Incoming audio call',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Status: ringing',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await callService.rejectIncomingCall();
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      },
                      icon: const Icon(Icons.call_end),
                      label: const Text('Decline Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        rootNavigatorKey.currentState?.pushReplacement(
                          MaterialPageRoute(builder: (_) => const CallScreen()),
                        );
                        await callService.acceptIncomingCall();
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Accept Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MessengerColors.messengerBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
