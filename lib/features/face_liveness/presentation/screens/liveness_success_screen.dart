import 'dart:io';

import 'package:flutter/material.dart';

class LivenessSuccessScreen extends StatelessWidget {
  final String message;
  final String? capturedPath;

  const LivenessSuccessScreen({
    super.key,
    required this.message,
    required this.capturedPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04141F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user,
                color: Color(0xFF00E0A4),
                size: 86,
              ),
              const SizedBox(height: 16),
              const Text(
                'Liveness Verified',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              if (capturedPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(capturedPath!),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF001018),
                  ),
                  child: const Text('Return to Chess'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
