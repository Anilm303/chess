import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'face_liveness_screen.dart';

class LivenessPermissionScreen extends StatefulWidget {
  const LivenessPermissionScreen({super.key});

  @override
  State<LivenessPermissionScreen> createState() =>
      _LivenessPermissionScreenState();
}

class _LivenessPermissionScreenState extends State<LivenessPermissionScreen> {
  bool _asking = false;

  Future<void> _grantAndContinue() async {
    if (_asking) return;
    setState(() => _asking = true);

    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (!mounted) return;
    setState(() => _asking = false);

    if (camera.isGranted && mic.isGranted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const FaceLivenessScreen()));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera and microphone permissions are required.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020B14),
      appBar: AppBar(
        title: const Text('Face Liveness'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, color: Color(0xFF00D4FF), size: 72),
              const SizedBox(height: 16),
              const Text(
                'Biometric Liveness Check',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We detect blink, head turn, smile and anti-spoof signals directly on device.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _asking ? null : _grantAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF001018),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _asking
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Allow & Start Verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
