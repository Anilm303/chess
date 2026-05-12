import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../navigation/app_navigator.dart';
import '../screens/incoming_call_screen.dart';
import '../services/call_service.dart';
import 'incoming_call_toast.dart';

class IncomingCallToastHost extends StatefulWidget {
  final Widget child;

  const IncomingCallToastHost({required this.child, super.key});

  @override
  State<IncomingCallToastHost> createState() => _IncomingCallToastHostState();
}

class _IncomingCallToastHostState extends State<IncomingCallToastHost> {
  bool _showToast = false;
  String _callerName = '';
  bool _openingIncomingCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final callService = context.read<CallService>();
    callService.addListener(_onCallStatusChanged);
  }

  void _onCallStatusChanged() {
    final callService = context.read<CallService>();
    if (callService.incomingCall != null &&
        callService.status == CallStatus.ringing) {
      if (!_showToast) {
        setState(() {
          _showToast = true;
          _callerName =
              callService.incomingCall?.callerDisplayName ?? 'Unknown';
        });
      }
    } else if (_showToast) {
      setState(() {
        _showToast = false;
      });
    }
  }

  void _dismissToast() {
    setState(() {
      _showToast = false;
    });
  }

  Future<void> _openIncomingCallPage() async {
    if (_openingIncomingCall) return;
    _openingIncomingCall = true;

    try {
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) return;

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const IncomingCallScreen(),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _openingIncomingCall = false;
    }
  }

  @override
  void dispose() {
    try {
      final callService = context.read<CallService>();
      callService.removeListener(_onCallStatusChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showToast)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: IncomingCallToast(
              callerName: _callerName,
              autoDismiss: false,
              duration: const Duration(seconds: 30),
              onDismiss: _dismissToast,
              onTap: () async {
                _dismissToast();
                await _openIncomingCallPage();
              },
            ),
          ),
      ],
    );
  }
}
